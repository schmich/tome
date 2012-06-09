require 'io/console'
require 'ward'
require 'passgen'

class CommandError < RuntimeError
end

class WardCommand
  private_class_method :new 

  def self.run(store_filename, args)
    command = new()
    return command.send(:run, store_filename, args)
  end

private
  def run(store_filename, args)
    @store_filename = store_filename
    
    if args.length < 1
      usage
      return 1
    end

    begin
      handle_command(args)
    rescue CommandError
      return 2
    end

    return 0
  end

  def handle_command(args)
    command = args[0]
    if command =~ /\A(help|-h|--h)\z/i
      # TODO: Implement.
    end

    case command
      when /\A(s|set)\z/i
        args.shift
        set(args)

      when /\A(g|get|show)\z/i
        args.shift
        get(args)

      when /\A(d|del|delete|rm|remove)\z/i
        args.shift
        delete(args)

      when /\A(gen|generate)\z/i
        args.shift
        generate(args)
    end
  end

  def set(args)
    if args.length > 3
      $stderr.puts $set_usage
      raise CommandError
    end
    
    opts = {}
    ward = new_ward()

    case args.length
      # ward new
      # ward set
      when 0
        opts.merge!(prompt_all_set())

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
      $stdout.print 'Created '
    else
      $stdout.print 'Updated '
    end
    
    $stdout.puts "password for #{format_id(opts)}."
  end

  def get(args)
    if args.length != 1
      $stderr.puts $get_usage
      raise CommandError
    end

    # ward get fb
    # ward get bar.com
    # ward get foo@bar.com
    id = parse_id(args[0])

    ward = new_ward()
    password = ward.get(id)

    if password.nil?
      $stderr.puts "No password for #{format_id(id)}."
    else
      $stdout.print password
    end
  end

  def delete(args)
    if args.length != 1
      $stderr.puts $delete_usage
      raise CommandError
    end

    # ward del fb
    # ward del bar.com
    # ward del foo@bar.com
    id = parse_id(args[0])

    ward = new_ward()
    deleted = ward.delete(id)

    if deleted
      $stdout.puts "Deleted password for #{format_id(id)}."
    else
      $stdout.puts "No password for #{format_id(id)}."
    end
  end

  def generate(args)
    if args.length > 2
      $stderr.puts $generate_usage
      raise CommandError
    end
    
    opts = {}
    ward = new_ward()

    case args.length
      # ward gen
      when 0
        opts.merge!(prompt_all_generate())

      # ward gen gmail.com
      # ward gen chris@gmail.com
      when 1
        opts.merge!(parse_username_domain(args[0]))

      # ward gen gmail.com gmail
      # ward gen chris@gmail.com gmail
      when 2
        opts.merge!(parse_username_domain(args[0]))
        opts.merge!(:nick => args[1])
    end

    opts.merge!(:password => generate_password())

    created = ward.set(opts)

    if created
      $stdout.puts "Generated password for #{format_id(opts)}."
    else
      $stdout.puts "Updated password for #{format_id(opts)} with generated value."
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

  def generate_password
    Passgen.generate(:length => 20, :symbols => true)
  end

  def prompt_all_set
    {}.merge!(prompt_domain())
      .merge!(prompt_password_username_nick())
  end

  def prompt_all_generate
    {}.merge!(prompt_domain())
      .merge!(prompt_username_nick())
  end

  def prompt_password_username_nick
    {}.merge!(prompt_password())
      .merge!(prompt_username_nick())
  end

  def prompt_password_nick
    {}.merge!(prompt_password())
      .merge!(prompt_nick())
  end

  def prompt_username_nick
    {}.merge!(prompt_username())
      .merge!(prompt_nick())
  end

  def prompt_domain
    $stderr.print 'Domain: '
    { :domain => $stdin.gets.strip }
  end

  def prompt_password
    begin
      $stderr.print 'Password: '
      password = get_password()

      $stderr.print 'Password (verify): '
      verify = get_password()

      if verify != password
        $stderr.puts 'Passwords do not match.'
        raise
      end
    rescue
      retry
    end

    { :password => password }
  end

  def prompt_username
    $stderr.print 'Username (optional): '
    username = $stdin.gets.strip
    if !username.empty?
      { :username => username }
    else
      {}
    end
  end

  def prompt_nick
    $stderr.print 'Nickname (optional): '
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
      $stderr.puts

      return password
    }
  end

  def new_ward
    begin
      $stderr.print 'Master password: '
      master_password = get_password()
      ward = Ward.new(@store_filename, master_password)
    rescue MasterPasswordError
      $stderr.puts 'Incorrect master password.'
      retry
    end

    return ward
  end

  def usage
    $stderr.puts $usage
  end
end

# TODO: Complete these.
$usage = <<USAGE
Usage:

  ward set
  ward get
  ward del
  ward gen
  ward help
USAGE

$set_usage = <<USAGE
Usage:

  ward set
  ward set [user@]<domain> [password]
  ward set [user@]<domain> <password> <nickname>

Examples:

  ward set gmail.com
  ward set gmail.com p4ssw0rd
  ward set gmail.com p4ssw0rd gmail
  ward set chris@gmail.com
  ward set chris@gmail.com p4ssw0rd
  ward set chris@gmail.com p4ssw0rd gmail

Alias: s, set
USAGE

$get_usage = <<USAGE
Usage:

  ward get <nickname>
  ward get [user@]<domain>

Examples:

  ward get gmail
  ward get gmail.com
  ward get chris@gmail.com

Alias: g, get, show
USAGE

$delete_usage = <<USAGE
Usage:

  ward del <nickname>
  ward del [user@]<domain>

Examples:

  ward del gmail
  ward del gmail.com
  ward del chris@gmail.com

Alias: d, del, delete, rm, remove
USAGE

$generate_usage = <<USAGE
Usage:

  ward gen
  ward gen [user@]<domain> [nickname]

Examples:

  ward gen
  ward gen gmail.com
  ward gen chris@gmail.com
  ward gen gmail.com gmail
  ward gen chris@gmail.com gmail

Alias: gen, generate
USAGE