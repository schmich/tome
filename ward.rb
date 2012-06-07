require 'yaml'
require 'fileutils'
require 'crypt'

class MasterPasswordError < RuntimeError
end

class Ward
  def initialize(store_filename, master_password)
    @store_filename = store_filename
    @master_password = master_password
  end

  def set(opts = {})
    return if opts.nil? || opts.empty?

    created = false

    write_store do |store|
      username = opts[:username]
      domain = opts[:domain]
      password = opts[:password]
      nick = opts[:nick]

      key = format_store_key(opts)
      return if key.nil?

      created = !store.include?(key)

      # TODO: Enforce nick uniqueness.
      store[key] = {}
      store[key]['username'] = username
      store[key]['domain'] = domain
      store[key]['password'] = password
      store[key]['nick'] = nick
    end

    return created
  end

  def get(opts = {})
    return nil if opts.nil? || opts.empty?

    password = nil

    read_store do |store|
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

    write_store do |store|
      if !opts[:nick].nil?
        deleted = delete_by_nick(store, opts)
      else
        deleted = delete_by_username_domain(store, opts)
      end
    end

    return deleted
  end

private
  def get_by_username_domain(store, opts)
    key = format_store_key(opts)
    return nil if key.nil?

    info = store[key]
    return nil if info.nil?

    return info['password']
  end

  def get_by_nick(store, opts)
    nick = opts[:nick]
    return nil if nick.nil?

    match = store.find { |key, info|
      !info['nick'].nil? && info['nick'].casecmp(nick) == 0
    }

    return nil if match.nil?

    return match['password']
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
      !info['nick'].nil? && info['nick'].casecmp(nick) == 0
    }.nil?

    return !same
  end
  
  def load_store()
    if !File.exist?(@store_filename)
      return {}
    else
      encrypted_yaml = File.open(@store_filename, 'rb') { |file| file.read }
      return {} if encrypted_yaml.length == 0

      begin
        yaml = Crypt.decrypt(
          :value => encrypted_yaml,
          :password => @master_password
        )
      rescue ArgumentError
        return {}
      rescue OpenSSL::Cipher::CipherError
        raise MasterPasswordError
      end

      store = YAML.load(yaml)
      return store ? store : {}
    end
  end

  def save_store(store)
    yaml = YAML.dump(store)

    encrypted_yaml = Crypt.encrypt(
      :value => yaml, 
      :password => @master_password
    )

    File.open(@store_filename, 'wb') do |out|
      out.write(encrypted_yaml)
    end
  end

  def read_store()
    store = load_store()
    yield store
    store = nil
  end

  def write_store()
    store = load_store()
    save = yield store
    save_store(store)
    store = nil
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
end