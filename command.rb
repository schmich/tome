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
      when /\A(set|s)\z/i
        args.shift
        set(args)

      when /\A(get|g|show)\z/i
        args.shift
        get(args)

      when /\A(delete|del|d|rm|remove)\z/i
        args.shift
        delete(args)

      when /\A(generate|gen)\z/i
        args.shift
        generate(args)

      when /\A(copy|cp)\z/i
        args.shift
        copy(args)

      when /\A(rename|ren|rn)\z/i
        # TODO
        $stderr.puts 'TODO'

      when /\A(list|ls)\z/i
        # TODO
        args.shift
        list(args)

      else
        raise CommandError, "Unrecognized command: #{command}.\n\n#{$usage}"
    end
  end

  def set(args)
    if args.length > 2
      raise CommandError, $set_usage
    end
    
    ward = ward_connect()

    case args.length
      # ward set
      when 0
        id = prompt_id()
        password = prompt_password()

      # TODO: Validate that first argument is in [username@]domain form.

      # ward set bar.com
      # ward set foo@bar.com
      when 1
        id = args[0]
        password = prompt_password()

      # ward set bar.com p4ssw0rd
      # ward set foo@bar.com p4ssw0rd
      when 2
        id = args[0]
        password = args[1]
    end

    created = ward.set(id, password)
    if created
      $stdout.print 'Created '
    else
      $stdout.print 'Updated '
    end

    $stdout.puts "password for #{id}."
  end

  def get(args)
    if args.length != 1
      raise CommandError, $get_usage
    end

    # ward get fb
    # ward get bar.com
    # ward get foo@bar.com
    pattern = args[0]

    ward = ward_connect()
    matches = ward.find(pattern)

    if matches.empty?
      raise CommandError, "No password found for #{pattern}."
    elsif matches.count == 1
      $stdout.puts matches.first.last
    else
      matches.each { |key, password|
        $stdout.puts "#{key}: #{password}"
      }
    end
  end

  def delete(args)
    if args.length != 1
      raise CommandError, $delete_usage
    end

    # ward del fb
    # ward del bar.com
    # ward del foo@bar.com
    id = args[0]

    ward = ward_connect()
    deleted = ward.delete(id)

    if deleted
      $stdout.puts "Deleted password for #{id}."
    else
      $stdout.puts "No password found for #{id}."
    end
  end

  def generate(args)
    if args.length > 1
      raise CommandError, $generate_usage
    end
    
    ward = ward_connect()

    case args.length
      # ward gen
      when 0
        id = prompt_id()

      # ward gen bar.com
      # ward gen foo@bar.com
      when 1
        id = args[0]
    end

    password = generate_password()
    created = ward.set(id, password)

    if created
      $stdout.puts "Generated password for #{id}:"
      $stdout.puts password
    else
      $stdout.puts "Updated password for #{id}:"
      $stdout.puts password
    end
  end

  def copy(args)
    if args.length != 1
      raise CommandError, $copy_usage
    end

    # ward cp fb
    # ward cp bar.com
    # ward cp foo@bar.com
    pattern = args[0]

    ward = ward_connect()
    matches = ward.find(pattern)

    if matches.empty?
      raise CommandError, "No password found for #{pattern}."
    elsif matches.count > 1
      message = "Found multiple matches for #{pattern}. Did you mean one of the following?\n\n"
      error.matches.each { |match|
        message += "\t#{match}\n"
      }

      raise CommandError, message
    else
      Clipboard.copy password
      if Clipboard.paste == password
        $stdout.puts "Password for #{pattern} copied to clipboard."
      else
        $stderr.puts "Failed to copy password for #{pattern} to clipboard."
      end
    end
  end

  def list(args)
    if !args.empty?
      raise CommandError, $list_usage
    end

    ward = ward_connect()

    count = 0
    ward.each_password { |id, password|
      $stdout.puts "#{id}: #{password}"
      count += 1
    }

    if count == 0
      $stdout.puts 'No passwords stored.'
    end
  end

  def generate_password
    Passgen.generate(:length => 20, :symbols => true)
  end

  def prompt_id
    # TODO: Validate input.
    $stderr.print 'Domain: '
    $stdin.gets.strip
  end

  def prompt_password
    begin
      $stderr.print 'Password: '
      password = input_password()

      if password.empty?
        $stderr.puts "Password cannot be blank. Use 'ward delete' to delete a password."
        raise
      end

      $stderr.print 'Password (verify): '
      verify = input_password()

      if verify != password
        $stderr.puts 'Passwords do not match.'
        raise
      end
    rescue
      retry
    end

    return password
  end

  def input_password
    $stdin.noecho { |stdin|
      password = stdin.gets.sub(/[\r\n]+\z/, '')
      $stderr.puts

      return password
    }
  end

  def ward_connect
    begin
      $stderr.print 'Master password: '
      master_password = input_password()
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

  ward set
  ward generate
  ward get
  ward copy
  ward list
  ward delete
  ward rename
  ward help
USAGE

$set_usage = <<USAGE
Usage:

  ward set
  ward set [user@]<domain> [password]

Examples:

  ward set
  ward set gmail.com
  ward set gmail.com p4ssw0rd
  ward set foo@gmail.com
  ward set foo@gmail.com p4ssw0rd

Alias: set, s
USAGE

$get_usage = <<USAGE
Usage:

  ward get [user@]<domain>

Examples:

  ward get gmail
  ward get gmail.com
  ward get foo@gmail.com

Alias: get, g, show
USAGE

$delete_usage = <<USAGE
Usage:

  ward delete [user@]<domain>

Examples:

  ward delete gmail
  ward delete gmail.com
  ward delete foo@gmail.com

Alias: delete, del, d, remove, rm
USAGE

$generate_usage = <<USAGE
Usage:

  ward generate
  ward generate [user@]<domain>

Examples:

  ward generate
  ward generate gmail.com
  ward generate foo@gmail.com

Alias: generate, gen
USAGE

$copy_usage = <<USAGE
Usage:

  ward copy [user@]<domain>

Examples:

  ward copy gmail
  ward copy gmail.com
  ward copy foo@gmail.com

Alias: copy, cp
USAGE

$list_usage = <<USAGE
Usage:

  ward list

Examples:

  ward list

Alias: list, ls
USAGE