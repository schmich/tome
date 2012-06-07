# TODO
# Option to allow/disallow enumeration (be more strict).
# Enforce nickname format (letters, underscore, number).
# More command-line verification.
# Better prompting for initial master password.
# Allow specification of master password on command-line, e.g. 'ward get gmail.com -- p4ssw0rd'
# Tests.

require 'yaml'
require 'fileutils'
require 'encryptor'
require 'io/console'

# TODO: Fix
$usage = <<USAGE
Usage: ward <command> [options]
  
  ward new
  ward set
  ward get
  ward del
  ward help
USAGE

class InvalidPasswordError < RuntimeError
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
        yaml = Encryptor.decrypt(
          :value => encrypted_yaml,
          :key => key,
          :algorithm => 'aes-256-cbc'
        )
      rescue ArgumentError
        @store = {}
      rescue OpenSSL::Cipher::CipherError
        raise InvalidPasswordError, 'Master password is incorrect.'
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
    encrypted_yaml = Encryptor.encrypt(
      :value => yaml, 
      :key => key,
      :algorithm => 'aes-256-cbc'
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

class WardCommand
  private_class_method :new 

  def self.run(args)
    command = new(args)
  end

  def initialize(args)
    exit(run(args))
  end

private
  def run(args)
    if args.length < 1
      usage
      return 1
    end

    command = args[0]
    if command =~ /\Ahelp\z/i
      # TODO: Implement.
    end

    begin
      print 'Master password: '
      password = get_password()
      ward = Ward.new(store_filename(), password)
    rescue InvalidPasswordError => error
      puts error.message
      return 2
    end

    case command
      when /\A(set|new|add)\z/i
        args.shift
        set(ward, args)

      when /\A(get|show)\z/i
        args.shift
        get(ward, args)

      when /\A(del|delete|rm)\z/i
        args.shift
        delete(ward, args)
    end

    return 0
  end

  def set(ward, args)
    opts = {}

    case args.length
      # ward new
      # ward set
      when 0
        opts.merge!(prompt_all())

      # ward set bar.com
      # ward set foo@bar.com
      when 1
        opts.merge!(parse_username_domain(args[0]))
        if opts[:username].nil?
          opts.merge!(prompt_password_username_nick())
        else
          opts.merge!(prompt_password_nick())
        end

      # ward set bar.com p4ssw0rd
      # ward set foo@bar.com p4ssw0rd
      when 2
        opts.merge!(parse_username_domain(args[0]))
        opts.merge!(:password => args[1])

      # ward set bar.com p4ssw0rd gmail
      # ward set foo@bar.com p4ssw0rd gmail
      when 3
        opts.merge!(parse_username_domain(args[0]))
        opts.merge!(:password => args[1], :nick => args[2])
    end

    created = ward.set(opts)
    if created
      print 'Created '
    else
      print 'Updated '
    end
    
    puts "password for #{format_id(opts)}."
  end

  def get(ward, args)
    if args.length != 1
      raise 'Invalid argument.'
    end

    # ward get fb
    # ward get bar.com
    # ward get foo@bar.com
    id = parse_id(args[0])

    password = ward.get(id)
    if password.nil?
      puts "No password for #{format_id(id)}."
    else
      puts password
    end
  end

  def delete(ward, args)
    if args.length != 1
      raise 'Invalid argument.'
    end

    # ward del fb
    # ward del bar.com
    # ward del foo@bar.com
    id = parse_id(args[0])

    deleted = ward.delete(id)
    if deleted
      puts "Deleted password for #{format_id(id)}."
    else
      puts "No password for #{format_id(id)}."
    end
  end

  def format_id(opts)
    return nil if opts.nil? || opts.empty?

    username = opts[:username]
    domain = opts[:domain]
    nick = opts[:nick]

    return nil if domain.nil? && nick.nil?

    if username.nil? && domain.nil?
      "#{nick}"
    else
      if username.nil?
        nick.nil? ? domain : "#{domain} (#{nick})"
      else
        nick.nil? ? "#{username}@#{domain}" : "#{username}@#{domain} (#{nick})"
      end
    end
  end

  def parse_id(string)
    opts = parse_username_domain(string)
    if opts[:domain] =~ /\./
      opts
    else
      { :nick => opts[:domain] }
    end
  end

  def parse_username_domain(string)
    opts = {}

    if string =~ /@/
      parts = string.split('@')
      opts[:username], opts[:domain] = parts.map(&:strip)
    else
      opts[:domain] = string.strip
    end

    return opts
  end

  def prompt_all
    {}.merge!(prompt_domain())
      .merge!(prompt_password())
      .merge!(prompt_username())
      .merge!(prompt_nick())
  end

  def prompt_password_username_nick
    {}.merge!(prompt_password())
      .merge!(prompt_username())
      .merge!(prompt_nick())
  end

  def prompt_password_nick
    {}.merge!(prompt_password())
      .merge!(prompt_nick())
  end

  def prompt_domain
    print 'Domain: '
    { :domain => $stdin.gets.strip }
  end

  def prompt_password
    begin
      print 'Password: '
      password = get_password()

      print 'Password (verify): '
      verify = get_password()

      if verify != password
        puts 'Passwords do not match.'
        raise
      end
    rescue
      retry
    end

    { :password => password }
  end

  def prompt_username
    print 'Username (optional): '
    username = $stdin.gets.strip
    if !username.empty?
      { :username => username }
    else
      {}
    end
  end

  def prompt_nick
    print 'Alias (optional): '
    nick = $stdin.gets.strip
    if !nick.empty?
      { :nick => nick }
    else
      {}
    end
  end

  def get_password
    $stdin.noecho { |stdin|
      password = stdin.gets.sub(/[\r\n]+\z/, '')
      puts

      return password
    }
  end

  def usage
    $stderr.puts $usage
  end

  def store_filename
    File.join(Dir.home, '.ward')
  end
end

WardCommand.run(ARGV)
