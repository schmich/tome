require 'io/console'
require 'ward'
require 'passgen'
require 'clipboard'

class CommandError < RuntimeError
end

class WardCommand
  private_class_method :new 

  def self.run(ward_filename, args)
    command = new()
    return command.send(:run, ward_filename, args)
  end

private
  def run(ward_filename, args)
    @ward_filename = ward_filename
    
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
    # TODO: Handle 'command --help', e.g. 'ward set --help'.

    command = command_from_arg(args[0])

    if command.nil?
      raise CommandError, "Unrecognized command: #{args[0]}.\n\n#{$usage}"
    end

    args.shift
    send(command, args) 
  end

  def command_from_arg(arg)
    commands = {
      /\A(help|(-h)|(--help))\z/i => :help,
      /\A(set|s)\z/i => :set,
      /\A(get|g|show)\z/i => :get,
      /\A(delete|del|d|rm|remove)\z/i => :delete,
      /\A(generate|gen)\z/i => :generate,
      /\A(copy|cp)\z/i => :copy,
      /\A(rename|ren|rn)\z/i => :rename,
      /\A(list|ls)\z/i => :list
    }

    commands.each { |pattern, command|
      return command if arg =~ pattern
    }

    return nil
  end

  def help(args)
    if args.length > 1
      raise CommandError, "Invalid arguments.\n\n#{$usage}"
    end

    if args.empty?
      $stdout.puts $usage
      return
    end

    command = command_from_arg(args[0])

    if command.nil?
      raise CommandError, "No help for unrecognized command: #{args[0]}.\n\n#{$usage}"
    end

    help = {
      :help => $help_usage,
      :set => $set_usage,
      :get => $get_usage,
      :delete => $delete_usage,
      :generate => $generate_usage,
      :copy => $copy_usage,
      :rename => $rename_usage,
      :list => $list_usage
    }

    $stdout.puts help[command]
  end

  def set(args)
    if args.length < 1 || args.length > 2
      raise CommandError, "Invalid arguments.\n\n#{$set_usage}"
    end
    
    ward = ward_create_connect()

    case args.length
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
      raise CommandError, "Invalid arguments.\n\n#{$get_usage}"
    end
    
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
      raise CommandError, "Invalid arguments.\n\n#{$delete_usage}"
    end

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
    if args.length != 1
      raise CommandError, "Invalid arguments.\n\n#{$generate_usage}"
    end
    
    ward = ward_create_connect()

    # ward gen bar.com
    # ward gen foo@bar.com
    id = args[0]
    password = generate_password()

    created = ward.set(id, password)

    if created
      $stdout.puts "Generated password for #{id}."
    else
      $stdout.puts "Updated #{id} with the generated password."
    end
  end

  def copy(args)
    if args.length != 1
      raise CommandError, "Invalid arguments.\n\n#{$copy_usage}"
    end

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
      match = matches.first
      password = match.last

      Clipboard.copy password
      if Clipboard.paste == password
        $stdout.puts "Password for #{match.first} copied to clipboard."
      else
        $stderr.puts "Failed to copy password for #{match.first} to clipboard."
      end
    end
  end

  def list(args)
    if !args.empty?
      raise CommandError, "Invalid arguments.\n\n#{$list_usage}"
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

  def rename(args)
    if args.count < 2
      raise CommandError, "Invalid arguments.\n\n#{$rename_usage}"
    end

    ward = ward_connect()

    old_id = args[0]
    new_id = args[1]

    renamed = ward.rename(old_id, new_id)
    
    if !renamed
      $stderr.puts "#{old_id} does not exist."
    else
      $stdout.puts "#{old_id} renamed to #{new_id}."
    end
  end

  def generate_password
    Passgen.generate(:length => 30, :symbols => true)
  end

  def prompt_password(prompt = 'Password')
    begin
      $stderr.print "#{prompt}: "
      password = input_password()

      if password.empty?
        $stderr.puts 'Password cannot be blank.'
        raise
      end

      $stderr.print "#{prompt} (verify): "
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
    if !Ward.exists?(@ward_filename)
      raise CommandError, "Ward database does not exist. Use 'ward set' or 'ward generate' to create a password first."
    end

    begin
      $stderr.print 'Master password: '
      master_password = input_password()
      ward = Ward.new(@ward_filename, master_password)
    rescue MasterPasswordError
      $stderr.puts 'Incorrect master password.'
      retry
    end

    return ward
  end

  def ward_create_connect
    if !Ward.exists?(@ward_filename)
      $stdout.puts 'Creating ward database.'
      master_password = prompt_password('Master password')
      ward = Ward.create!(@ward_filename, master_password)
    else
      ward = ward_connect()
    end
  end
end

# TODO: Complete these.
$usage = <<END
Usage:

    ward set [user@]<domain> [password]

        Create or update the password for an account.
        Example: ward set foo@gmail.com

    ward generate [user@]<domain>

        Generate a random password for an account.
        Example: ward generate reddit.com

    ward get <pattern>

        Show the passwords for all accounts matching the pattern.
        Example: ward get youtube

    ward copy <pattern>

        Copy the password for the account matching the pattern.
        Example: ward copy news.ycombinator.com

    ward list

        Show all stored accounts and passwords.
        Example: ward list

    ward delete [user@]<domain>

        Delete the password for an account.
        Example: ward delete foo@slashdot.org

    ward rename <old> <new>

        Rename the account information stored.
        Example: ward rename twitter.com foo@twitter.com

    ward help

        Shows help for a specific command.
        Example: ward help set
END

$help_usage = <<END
ward help

    Shows help for a specific command.

Usage:

    ward help
    ward help <command>

Examples:

    ward help
    ward help set
    ward help help (so meta)

Alias: help, --help, -h
END

$set_usage = <<END
ward set

    Create or update the password for an account. The user is optional.
    If you do not specify a password, you will be prompted for one.

Usage:

    ward set [user@]<domain> [password]

Examples:

    ward set gmail.com
    ward set gmail.com p4ssw0rd
    ward set foo@gmail.com
    ward set foo@gmail.com p4ssw0rd

Alias: set, s
END

$get_usage = <<END
ward get

    Show the passwords for all accounts matching the pattern.
    Matching is done with substring search. Wildcards are not supported.

Usage:

    ward get <pattern>

Examples:

    ward get gmail
    ward get foo@
    ward get foo@gmail.com

Alias: get, g, show
END

$delete_usage = <<END
ward delete

    Delete the password for an account.

Usage:

    ward delete [user@]<domain>

Examples:

    ward delete gmail.com
    ward delete foo@gmail.com

Alias: delete, del, d, remove, rm
END

$generate_usage = <<END
ward generate

    Generate a random password for an account. The user is optional.

Usage:

    ward generate [user@]<domain>

Examples:

    ward generate gmail.com
    ward generate foo@gmail.com

Alias: generate, gen
END

$copy_usage = <<END
ward copy

    Copy the password for the account matching the pattern.
    If more than one account matches the pattern, nothing happens.
    Matching is done with substring search. Wildcards are not supported.

Usage:

    ward copy <pattern>

Examples:

    ward copy gmail
    ward copy foo@
    ward copy foo@gmail.com

Alias: copy, cp
END

$list_usage = <<END
ward list

    Show all stored accounts and passwords.

Usage:

    ward list

Examples:

    ward list

Alias: list, ls
END

$rename_usage = <<END
ward rename

    Rename the account information stored.

Usage:

    ward rename <old> <new>

Examples:

    ward rename gmail.com foo@gmail.com
    ward rename foo@gmail.com bar@gmail.com

Alias: rename, ren, rn
END