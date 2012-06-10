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
      raise WardError, 'You must specify an ID or pattern.'
    end

    id = nil

    writable_store do |store|
      if !opts[:id].nil?
        id = set_by_id(store, opts)
      elsif !opts[:pattern].nil?
        id = set_by_pattern(store, opts)
      else
        raise WardError, 'You must specify a domain.'
      end
    end

    return id
  end

  def get(opts = {})
    if opts.nil? || opts.empty?
      raise WardError, 'You must specify a domain.'
    end

    password = nil

    readable_store do |store|
      if !opts[:id].nil?
        password = get_entry(store, opts)
      else
        raise WardError, 'You must specify a domain.'
      end
    end

    return password
  end

  def delete(opts = {})
    if opts.nil? || opts.empty?
      raise WardError, 'You must specify a domain.'
    end

    deleted = false

    writable_store do |store|
      if !opts[:id].nil?
        deleted = delete_entry(store, opts)
      else
        raise WardError, 'You must specify a domain.'
      end
    end

    return deleted
  end

private
  def set_by_id(store, opts)
    key = opts[:id]

    store[key] = {}
    store[key][:password] = opts[:password]

    return key
  end

  def set_by_pattern(store, opts)
    pattern = opts[:pattern]

    entries = find_entries_by_pattern(store, pattern)

    if entries.empty?
      raise WardError, "No entries found matching \"#{pattern}\"."
    elsif entries.count > 1
      raise WardError, "\"#{pattern}\" is ambiguous, multiple entries found."
    end

    entry = entries.first

    entry.last[:password] = opts[:password]
    return entry.first
  end

  def get_entry(store, opts)
    entry = find_entry_by_id(store, opts)

    return nil if entry.nil? || entry.last.nil?

    return entry.last[:password]
  end

  def delete_entry(store, opts)
    name = opts[:id]
    return false if name.nil?

    same = store.reject! { |key, info|
      key.casecmp(name) == 0
    }.nil?

    return !same
  end

  def find_entry_by_id(store, opts)
    name = opts[:id]
    return nil if name.nil?

    return store.find { |key, info|
      !key.nil? && key.casecmp(name) == 0
    }
  end

  def find_entries_by_pattern(store, pattern)
    return [] if pattern.nil?

    return store.select { |key, info|
      key =~ /#{pattern}/i
    }
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

    # TODO: Throw if these values are nil.
    # TODO: Verify version number, raise if incompatible.
    values = {
      :version => FILE_VERSION,
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

    contents = {
      :version => FILE_VERSION,
      :salt => salt,
      :iv => iv, 
      :stretch => stretch,
      :store => encrypted_store
    }

    File.open(@store_filename, 'wb') do |file|
      YAML.dump(contents, file)
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

  def authenticate
    # Force a read.
    # If the master password is invalid, the access exception will propagate.
    readable_store { }
  end

  FILE_VERSION = 1
end