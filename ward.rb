require 'yaml'
require 'fileutils'
require 'crypt'

class MasterPasswordError < RuntimeError
end

class Ward
  def initialize(store_filename, master_password, default_stretch = 100_000)
    @store_filename = store_filename
    @master_password = master_password
    @default_stretch = default_stretch
    authenticate()
  end

  def set(opts = {})
    if opts.nil? || opts.empty? || opts[:password].nil?
      raise ArgumentError
    end

    return writable_store do |store|
      if !opts[:id].nil?
        set_by_id(store, opts)
      else
        raise ArgumentError
      end
    end
  end

  def find(pattern)
    if pattern.nil? || pattern.empty?
      raise ArgumentError
    end

    return readable_store do |store|
      get_by_pattern(store, pattern)
    end
  end

  def get(id)
    if id.nil? || id.empty?
      raise ArgumentError
    end

    return readable_store do |store|
      get_by_id(store, id)
    end
  end

  def delete(opts = {})
    if opts.nil? || opts.empty?
      raise ArgumentError
    end

    return writable_store do |store|
      if !opts[:id].nil?
        delete_entry(store, opts)
      else
        raise ArgumentError
      end
    end
  end

private
  def set_by_id(store, opts)
    id = opts[:id]

    created = !store.include?(id)

    store[id] = {}
    store[id][:password] = opts[:password]

    return created
  end

  def get_by_id(store, opts)
    entry = find_by_id(store, opts[:id])

    return nil if entry.nil? || entry.last.nil?

    return [entry]
  end

  def get_by_pattern(store, pattern)
    find_by_pattern(store, pattern).map { |key, value|
      { key => value[:password] }
    }.inject { |hash, item|
      hash.merge!(item)
    } || {}
  end

  def delete_entry(store, opts)
    name = opts[:id]
    return false if name.nil?

    same = store.reject! { |key, info|
      key.casecmp(name) == 0
    }.nil?

    return !same
  end

  def find_by_id(store, id)
    return nil if id.nil?

    # TODO: Throw IdNotFoundError?

    return store.find { |key, info|
      !key.nil? && key.casecmp(id) == 0
    }
  end

  def find_by_pattern(store, pattern)
    return {} if pattern.nil?

    # TODO: Better matching. Should allow separated
    # substring matching. Exact match > solid substrings > separated substrings.

    exact = store.select { |key, info|
      key.casecmp(pattern) == 0
    }

    return exact if !exact.empty?

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

    result = yield store

    store = nil
    GC.start

    return result
  end

  def writable_store()
    values = load_store() || new_store

    store = values[:store]
    salt = values[:salt]
    iv = values[:iv]
    stretch = values[:stretch]

    result = yield store

    save_store(store, salt, iv, stretch)
    store = nil

    GC.start

    return result
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