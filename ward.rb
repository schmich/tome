require 'yaml'
require 'fileutils'
require 'crypt'

class MasterPasswordError < RuntimeError
end

class WardError < RuntimeError
end

class Ward
  def initialize(store_filename, master_password, default_stretch = 100_000)
    @store_filename = store_filename
    @master_password = master_password
    @default_stretch = default_stretch
    authenticate()
  end

  # TODO: Return a value or throw an exception
  # if parameters are invalid.
  def set(opts = {})
    if opts.nil? || opts.empty?
      raise WardError, 'You must specify a domain or nickname.'
    end

    created = false

    writable_store do |store|
      if !opts[:domain].nil?
        created = set_by_username_domain(store, opts)
      elsif !opts[:nick].nil?
        created = set_by_nick(store, opts)
      else
        raise WardError, 'You must specify a domain or nickname.'
      end
    end

    return created
  end

  def get(opts = {})
    return nil if opts.nil? || opts.empty?

    password = nil

    readable_store do |store|
      if !opts[:nick].nil?
        password = get_by_nick(store, opts)
      else
        password = get_by_username_domain(store, opts)
      end
    end

    return password
  end

  def delete(opts = {})
    return if opts.nil? || opts.empty?

    deleted = false

    writable_store do |store|
      if !opts[:nick].nil?
        deleted = delete_by_nick(store, opts)
      else
        deleted = delete_by_username_domain(store, opts)
      end
    end

    return deleted
  end

private
  def set_by_nick(store, opts)
    entry = entry_by_nick(store, opts)

    if entry.nil? || entry.last.nil?
      raise WardError, "No information found for nickname #{opts[:nick]}."
    end

    entry.last[:password] = opts[:password]

    return false
  end

  def set_by_username_domain(store, opts)
    key = format_store_key(opts)
    return false if key.nil?

    ensure_nick_unique(store, opts)

    created = !store.include?(key)

    store[key] = {}
    store[key][:username] = opts[:username]
    store[key][:domain] = opts[:domain]
    store[key][:password] = opts[:password]
    store[key][:nick] = opts[:nick]

    return created
  end

  def ensure_nick_unique(store, opts)
    nick = opts[:nick]
    return if nick.nil?

    entry = entry_by_nick(store, opts)
    return if entry.nil? || entry.last.nil?

    domain = opts[:domain]
    username = opts[:username]

    if domain.casecmp(entry.last[:domain]) != 0
      raise WardError, "Nickname #{nick} is already in use."
    end

    if !username.nil?
      if username.casecmp(entry.last[:username]) != 0
        raise WardError, "Nickname #{nick} is already in use."
      end
    end
  end

  def get_by_username_domain(store, opts)
    entry = entry_by_username_domain(store, opts)

    return nil if entry.nil? || entry.last.nil?

    return entry.last[:password]
  end

  def get_by_nick(store, opts)
    entry = entry_by_nick(store, opts)

    return nil if entry.nil? || entry.last.nil?

    return entry.last[:password]
  end

  def entry_by_username_domain(store, opts)
    find_key = format_store_key(opts)
    return nil if find_key.nil?

    return store.find { |key, info|
      !key.nil? && key.casecmp(find_key) == 0
    }
  end

  def entry_by_nick(store, opts)
    nick = opts[:nick]
    return nil if nick.nil?

    return store.find { |key, info|
      !info[:nick].nil? && info[:nick].casecmp(nick) == 0
    }
  end

  def delete_by_username_domain(store, opts)
    key = format_store_key(opts)
    return false if key.nil?

    same = store.reject! { |entry_key, info|
      entry_key.casecmp(key) == 0
    }.nil?

    return !same
  end

  def delete_by_nick(store, opts)
    nick = opts[:nick]
    return nil if nick.nil?

    same = store.reject! { |key, info|
      !info[:nick].nil? && info[:nick].casecmp(nick) == 0
    }.nil?

    return !same
  end
  
  def load_store()
    if !File.exist?(@store_filename)
      return nil
    end

    contents = File.open(@store_filename, 'rb') { |file| file.read }
    if contents.length == 0
      return nil
    end

    config = YAML.load(contents)
    values = {
      :salt => config[:salt],
      :iv => config[:iv],
      :stretch => config[:stretch]
    }

    encrypted_store = config[:store]
    return values if encrypted_store.nil? || encrypted_store.empty?

    begin
      store_yaml = Crypt.decrypt(
        :value => encrypted_store,
        :password => @master_password,
        :stretch => values[:stretch],
        :salt => values[:salt],
        :iv => values[:iv]
      )
    rescue ArgumentError
      return values.merge(:store => {})
    rescue OpenSSL::Cipher::CipherError
      raise MasterPasswordError
    end

    store = YAML.load(store_yaml)
    return values.merge(:store => (store ? store : {}))
  end

  def save_store(store, salt, iv, stretch)
    yaml = YAML.dump(store)

    encrypted_store = Crypt.encrypt(
      :value => yaml, 
      :password => @master_password,
      :salt => salt,
      :iv => iv,
      :stretch => stretch
    )

    content = {
      :salt => salt,
      :iv => iv, 
      :stretch => stretch,
      :store => encrypted_store
    }

    File.open(@store_filename, 'wb') do |file|
      YAML.dump(content, file)
    end
  end

  def readable_store()
    values = load_store || new_store
    store = values[:store]

    yield store

    store = nil
    GC.start
  end

  def writable_store()
    values = load_store() || new_store

    # TODO: Throw if these values are nil.

    store = values[:store]
    salt = values[:salt]
    iv = values[:iv]
    stretch = values[:stretch]

    yield store

    save_store(store, salt, iv, stretch)
    store = nil

    GC.start
  end

  def new_store
    {
      :store => {},
      :salt => Crypt.new_salt,
      :iv => Crypt.new_iv,
      :stretch => @default_stretch
    }
  end

  def format_store_key(opts)
    username = opts[:username]
    domain = opts[:domain]

    return nil if domain.nil?

    if username.nil?
      domain
    else
      "#{username}@#{domain}"
    end
  end

  def authenticate
    # Force a read.
    # If the master password is invalid, the access exception will propagate.
    readable_store { }
  end

  FILE_FORMAT_VERSION = 1
end