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
        args.shift
        rename(args)

      when /\A(list|ls)\z/i
        args.shift
        list(args)

      else
        raise CommandError, "Unrecognized command: #{command}.\n\n#{$usage}"
    end
  end

  def set(args)
    if args.length < 1 || args.length > 2
      raise CommandError, $set_usage
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
      raise CommandError, $get_usage
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
      raise CommandError, $delete_usage
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
      raise CommandError, $generate_usage
    end
    
    ward = ward_create_connect()

    # ward gen bar.com
    # ward gen foo@bar.com
    id = args[0]
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

  def rename(args)
    if args.count < 2
      raise CommandError, $rename_usage
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

  ward set
  ward generate

  ward get
  ward copy
  ward list

  ward delete
  ward rename

  ward help
END

$set_usage = <<END
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
Usage:

  ward get [user@]<domain>

Examples:

  ward get gmail.com
  ward get foo@gmail.com

Alias: get, g, show
END

$delete_usage = <<END
Usage:

  ward delete [user@]<domain>

Examples:

  ward delete gmail.com
  ward delete foo@gmail.com

Alias: delete, del, d, remove, rm
END

$generate_usage = <<END
Usage:

  ward generate [user@]<domain>

Examples:

  ward generate gmail.com
  ward generate foo@gmail.com

Alias: generate, gen
END

$copy_usage = <<END
Usage:

  ward copy [user@]<domain>

Examples:

  ward copy gmail.com
  ward copy foo@gmail.com

Alias: copy, cp
END

$list_usage = <<END
Usage:

  ward list

Examples:

  ward list

Alias: list, ls
END

$rename_usage = <<END
Usage:

  ward rename <old> <new>

Examples:

  ward rename gmail.com foo@gmail.com
  ward rename foo@gmail.com bar@gmail.com

Alias: rename, ren, rn
END