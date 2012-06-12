require 'yaml'
require 'fileutils'

module Tome
  class MasterPasswordError < RuntimeError
  end

  class Tome
    def self.exists?(tome_filename)
      return !load_tome(tome_filename).nil?
    end

    def self.create!(tome_filename, master_password, stretch = 100_000)
      save_tome(tome_filename, new_tome(stretch), {}, master_password)
      return Tome.new(tome_filename, master_password)
    end

    def initialize(tome_filename, master_password)
      @tome_filename = tome_filename
      @master_password = master_password

      # TODO: This is suboptimal. We are loading the store
      # twice for most operations because of this authentication.
      authenticate()
    end

    def set(id, password)
      if id.nil? || id.empty? || password.nil? || password.empty?
        raise ArgumentError
      end

      return writable_store do |store|
        set_by_id(store, id, password)
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

    def find(pattern)
      if pattern.nil? || pattern.empty?
        raise ArgumentError
      end

      return readable_store do |store|
        get_by_pattern(store, pattern)
      end
    end

    def delete(id)
      if id.nil? || id.empty?
        raise ArgumentError
      end

      return writable_store do |store|
        delete_by_id(store, id)
      end
    end

    def rename(old_id, new_id)
      if old_id.nil? || old_id.empty? || new_id.nil? || new_id.empty?
        raise ArgumentError
      end

      return writable_store do |store|
        rename_by_id(store, old_id, new_id)
      end
    end

    def each_password
      if !block_given?
        raise ArgumentError
      end

      readable_store do |store|
        store.each { |id, info|
          yield id, info[:password]
        }
      end 
    end

  private
    def set_by_id(store, id, password)
      created = !store.include?(id)

      store[id] = {}
      store[id][:password] = password

      return created
    end

    def get_by_pattern(store, pattern)
      find_by_pattern(store, pattern).map { |key, value|
        { key => value[:password] }
      }.inject { |hash, item|
        hash.merge!(item)
      } || {}
    end

    def get_by_id(store, id)
      store[id]
    end

    def delete_by_id(store, id)
      same = store.reject! { |key, info|
        key.casecmp(id) == 0
      }.nil?

      return !same
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
    
    def rename_by_id(store, old_id, new_id)
      if store[old_id].nil?
        return false
      else
        values = store[old_id]
        store.delete(old_id)
        store[new_id] = values
        return true
      end
    end

    def self.load_tome(tome_filename)
      return nil if !File.exist?(tome_filename)

      contents = File.open(tome_filename, 'rb') { |file| file.read }
      return nil if contents.length == 0

      values = YAML.load(contents)
      return nil if !values

      # TODO: Throw if these values are nil.
      # TODO: Verify version number, raise if incompatible.
      return {
        :version => values[:version],
        :salt => values[:salt],
        :iv => values[:iv],
        :stretch => values[:stretch],
        :store => values[:store] 
      }
    end

    def load_store(tome)
      if tome.nil?
        raise ArgumentError
      end

      begin
        store_yaml = Crypt.decrypt(
          :value => tome[:store],
          :password => @master_password,
          :stretch => tome[:stretch],
          :salt => tome[:salt],
          :iv => tome[:iv]
        )
      rescue ArgumentError
        # TODO: Should probably be raising an error here.
        return {}
      rescue OpenSSL::Cipher::CipherError
        raise MasterPasswordError
      end

      store = YAML.load(store_yaml)
      return store || {}
    end

    def self.save_tome(tome_filename, tome, store, master_password)
      if tome.nil? || store.nil? || master_password.nil? || master_password.empty?
        raise ArgumentError
      end

      store_yaml = YAML.dump(store)

      new_salt = Crypt.new_salt
      new_iv = Crypt.new_iv

      encrypted_store = Crypt.encrypt(
        :value => store_yaml, 
        :password => master_password,
        :salt => new_salt,
        :iv => new_iv,
        :stretch => tome[:stretch]
      )

      contents = tome.merge({
        :version => FILE_VERSION,
        :store => encrypted_store,
        :salt => new_salt,
        :iv => new_iv
      })

      File.open(tome_filename, 'wb') do |file|
        YAML.dump(contents, file)
      end
    end

    def readable_store()
      tome = Tome.load_tome(@tome_filename)
      store = load_store(tome)

      result = yield store

      store = nil
      GC.start

      return result
    end

    def writable_store()
      tome = Tome.load_tome(@tome_filename)
      store = load_store(tome)

      result = yield store

      Tome.save_tome(@tome_filename, tome, store, @master_password)
      store = nil

      GC.start

      return result
    end

    def self.new_tome(stretch)
      {
        :store => {},
        :salt => Crypt.new_salt,
        :iv => Crypt.new_iv,
        :stretch => stretch
      }
    end

    def authenticate
      # Force a read.
      # If the master password is invalid, the access exception will propagate.
      readable_store { }
    end

    FILE_VERSION = 1
  end
end
