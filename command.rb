require 'io/console'
require 'ward'
require 'passgen'
require 'clipboard'

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
      $stderr.puts $usage
      return 1
    end

    begin
      handle_command(args)
    rescue CommandError => error
      $stderr.puts error.message
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
      when /\A(new|n)\z/i
        args.shift
        do_new(args)

      when /\A(update|u|set|s)\z/i
        args.shift
        do_update(args)

      when /\A(g|get|show)\z/i
        args.shift
        do_get(args)

      when /\A(d|del|delete|rm|remove)\z/i
        args.shift
        do_delete(args)

      when /\A(gen|generate)\z/i
        args.shift
        do_generate(args)

      when /\A(cp|copy)\z/i
        args.shift
        do_copy(args)

      else
        raise CommandError, "Unrecognized command: #{command}." 
    end
  end

  def do_new(args)
    if args.length > 2
      raise CommandError, $new_usage
    end
    
    opts = {}
    ward = ward_connect()

    case args.length
      # ward new
      when 0
        opts.merge!(prompt_all_new())

      # TODO: Validate that first argument is in [username@]domain form.

      # ward new bar.com
      # ward new foo@bar.com
      when 1
        opts.merge!(:id => args[0])
        opts.merge!(prompt_password)

      # ward new bar.com p4ssw0rd
      # ward new foo@bar.com p4ssw0rd
      when 2
        opts.merge!(:id => args[0], :password => args[1])
    end

    id = ward.set(opts)
    $stdout.puts "Created password for #{id}."
  end

  def do_update(args)
    if args.length > 2
      raise CommandError, $update_usage
    end
    
    opts = {}
    ward = ward_connect()

    case args.length
      # ward update
      when 0
        opts.merge!(prompt_all_update())

      # TODO: Validate that first argument is in [username@]domain form.

      # ward update bar.com
      # ward update foo@bar.com
      when 1
        opts.merge!(:pattern => args[0])
        opts.merge!(prompt_password)

      # ward update bar.com p4ssw0rd
      # ward update foo@bar.com p4ssw0rd
      when 2
        opts.merge!(:pattern => args[0], :password => args[1])
    end

    id = ward.set(opts)
    $stdout.puts "Updated password for #{id}."
  end

  def do_get(args)
    if args.length != 1
      raise CommandError, $get_usage
    end

    # ward get fb
    # ward get bar.com
    # ward get foo@bar.com
    opts = { :id => args[0] }

    ward = ward_connect()
    password = ward.get(opts)

    if password.nil?
      $stderr.puts "No password for #{opts[:id]}."
    else
      $stdout.puts password
    end
  end

  def do_delete(args)
    if args.length != 1
      raise CommandError, $delete_usage
    end

    # ward del fb
    # ward del bar.com
    # ward del foo@bar.com
    opts = { :id => args[0] }

    ward = ward_connect()
    deleted = ward.delete(opts)

    if deleted
      $stdout.puts "Deleted password for #{opts[:id]}."
    else
      $stdout.puts "No password for #{opts[:id]}."
    end
  end

  def do_generate(args)
    if args.length > 1
      raise CommandError, $generate_usage
    end
    
    opts = {}
    ward = ward_connect()

    case args.length
      # ward gen
      when 0
        opts.merge!(prompt_all_generate())

      # ward gen gmail.com
      # ward gen chris@gmail.com
      when 1
        opts.merge!(:id => args[0])
    end

    opts.merge!(:password => generate_password())

    created = ward.set(opts)

    if created
      $stdout.puts "Generated password for #{opts[:id]}."
    else
      $stdout.puts "Updated password for #{opts[:id]} with generated value."
    end
  end

  def do_copy(args)
    if args.length != 1
      raise CommandError, $copy_usage
    end

    # ward cp fb
    # ward cp bar.com
    # ward cp foo@bar.com
    opts = { :id => args[0] }

    ward = ward_connect()
    password = ward.get(opts)

    if password.nil?
      $stderr.puts "No password for #{opts[:id]}."
    else
      Clipboard.copy password
      if Clipboard.paste == password
        $stdout.puts "Password for #{opts[:id]} copied to clipboard."
      else
        $stderr.puts "Failed to copy password for #{opts[:id]} to clipboard."
      end
    end
  end

  def generate_password
    Passgen.generate(:length => 20, :symbols => true)
  end

  def prompt_all_new
    {}.merge!(prompt_name())
      .merge!(prompt_password())
  end

  def prompt_all_update
    {}.merge!(prompt_name())
      .merge!(prompt_password())
  end

  def prompt_all_generate
    {}.merge!(prompt_name())
  end

  def prompt_name
    # TODO: Validate input.
    $stderr.print 'Domain: '
    { :id => $stdin.gets.strip }
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

  def get_password
    $stdin.noecho { |stdin|
      password = stdin.gets.sub(/[\r\n]+\z/, '')
      $stderr.puts

      return password
    }
  end

  def ward_connect
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
end

# TODO: Complete these.
$usage = <<USAGE
Usage:

  ward new
  ward update
  ward get
  ward delete
  ward generate
  ward copy
  ward help
USAGE

$new_usage = <<USAGE
Usage:

  ward new
  ward new [user@]<domain> [password]

Examples:

  ward new
  ward new gmail.com
  ward new gmail.com p4ssw0rd
  ward new chris@gmail.com
  ward new chris@gmail.com p4ssw0rd

Alias: new, n
USAGE

$update_usage = <<USAGE
Usage:

  ward update
  ward update [user@]<domain> [password]

Examples:

  ward update gmail.com
  ward update gmail.com p4ssw0rd
  ward update chris@gmail.com
  ward update chris@gmail.com p4ssw0rd

Alias: update, u, set, s
USAGE

$get_usage = <<USAGE
Usage:

  ward get [user@]<domain>

Examples:

  ward get gmail
  ward get gmail.com
  ward get chris@gmail.com

Alias: get, g, show
USAGE

$delete_usage = <<USAGE
Usage:

  ward delete [user@]<domain>

Examples:

  ward delete gmail
  ward delete gmail.com
  ward delete chris@gmail.com

Alias: delete, del, d, remove, rm
USAGE

$generate_usage = <<USAGE
Usage:

  ward generate
  ward generate [user@]<domain>

Examples:

  ward generate
  ward generate gmail.com
  ward generate chris@gmail.com

Alias: generate, gen
USAGE

$copy_usage = <<USAGE
Usage:

  ward copy [user@]<domain>

Examples:

  ward copy gmail
  ward copy gmail.com
  ward copy chris@gmail.com

Alias: copy, cp
USAGE