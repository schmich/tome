# TODO
# Option to allow/disallow enumeration (be more strict).
# Enforce nickname format (letters, underscore, number).
# More command-line verification.
# Better prompting for initial master password.
# Allow specification of master password on command-line, e.g. 'ward get gmail.com -- p4ssw0rd'
# Tests.

require 'yaml'
require 'fileutils'
require 'crypt'

class MasterPasswordError < RuntimeError
end

class Ward
  def initialize(store_filename, master_password)
    @store_filename = store_filename
    @master_password = master_password
    load_store()
  end

  def set(opts = {})
    return if opts.nil? || opts.empty?

    username = opts[:username]
    domain = opts[:domain]
    password = opts[:password]
    nick = opts[:nick]

    key = format_key(opts)
    return if key.nil?

    created = !@store.include?(key)

    # TODO: Enforce nick uniqueness.
    @store[key] = {}
    @store[key]['username'] = username
    @store[key]['domain'] = domain
    @store[key]['password'] = password
    @store[key]['nick'] = nick

    save_store()

    return created
  end

  def get(opts = {})
    return nil if opts.nil? || opts.empty?

    if !opts[:nick].nil?
      get_by_nick(opts)
    else
      get_by_username_domain(opts)
    end
  end

  def delete(opts = {})
    return if opts.nil? || opts.empty?

    if !opts[:nick].nil?
      deleted = delete_by_nick(opts)
    else
      deleted = delete_by_username_domain(opts)
    end

    save_store()

    return deleted
  end

private
  def get_by_username_domain(opts)
    key = format_key(opts)
    return nil if key.nil?

    info = @store[key]
    return nil if info.nil?

    return info['password']
  end

  def get_by_nick(opts)
    nick = opts[:nick]
    return nil if nick.nil?

    match = @store.find { |key, info|
      !info['nick'].nil? && info['nick'].casecmp(nick) == 0
    }

    return nil if match.nil?

    return match['password']
  end

  def delete_by_username_domain(opts)
    key = format_key(opts)
    return false if key.nil?

    same = @store.reject! { |entry_key, info|
      entry_key.casecmp(key) == 0
    }.nil?

    return !same
  end

  def delete_by_nick(opts)
    nick = opts[:nick]
    return nil if nick.nil?

    same = @store.reject! { |key, info|
      !info['nick'].nil? && info['nick'].casecmp(nick) == 0
    }.nil?

    return !same
  end
  
  def load_store()
    if !File.exist?(@store_filename)
      @store = {}
    else
      encrypted_yaml = File.read(@store_filename)

      begin
        key = Digest::SHA256.hexdigest(@master_password)
        yaml = Crypt.decrypt(
          :value => encrypted_yaml,
          :key => key
        )
      rescue ArgumentError
        @store = {}
      rescue OpenSSL::Cipher::CipherError
        raise MasterPasswordError
      end

      @store = YAML.load(yaml)
      if !@store
        @store = {}
      end
    end
  end

  def save_store()
    yaml = YAML.dump(@store)
    key = Digest::SHA256.hexdigest(@master_password)
    encrypted_yaml = Crypt.encrypt(
      :value => yaml, 
      :key => key
    )

    File.open(@store_filename, 'wb') do |out|
      out.write(encrypted_yaml)
    end
  end

  def format_key(opts)
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