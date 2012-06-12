require 'io/console'
require 'passgen'
require 'clipboard'

module Tome
  class CommandError < RuntimeError
  end

  class Command
    private_class_method :new 

    def self.run(tome_filename, args, stdout = $stdout, stderr = $stderr, stdin = $stdin)
      command = new()
      return command.send(:run, tome_filename, args, stdout, stderr, stdin)
    end

  private
    def run(tome_filename, args, stdout, stderr, stdin)
      @out = stdout
      @err = stderr
      @in = stdin
      @tome_filename = tome_filename
      
      if args.length < 1
        @err.puts $usage
        return 1
      end

      begin
        handle_command(args)
      rescue CommandError => error
        @err.puts error.message
        return 1
      end

      return 0
    end

    def handle_command(args)
      # TODO: Handle 'command --help', e.g. 'tome set --help'.

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
        @out.puts $usage
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

      @out.puts help[command]
    end

    def set(args)
      if args.length < 1 || args.length > 2
        raise CommandError, "Invalid arguments.\n\n#{$set_usage}"
      end
      
      tome = tome_create_connect()

      case args.length
        # TODO: Validate that first argument is in [username@]domain form.

        # tome set bar.com
        # tome set foo@bar.com
        when 1
          id = args[0]
          password = prompt_password()

        # tome set bar.com p4ssw0rd
        # tome set foo@bar.com p4ssw0rd
        when 2
          id = args[0]
          password = args[1]
      end

      exists = !tome.get(id).nil?
      if exists
        confirm = prompt_confirm("A password already exists for #{id}. Overwrite (y/n)? ")
        if !confirm
          raise CommandError, 'Aborted.'
        end
      end

      created = tome.set(id, password)
      if created
        @out.print 'Created '
      else
        @out.print 'Updated '
      end

      @out.puts "password for #{id}."
    end

    def get(args)
      if args.length != 1
        raise CommandError, "Invalid arguments.\n\n#{$get_usage}"
      end
      
      # tome get bar.com
      # tome get foo@bar.com
      pattern = args[0]

      tome = tome_connect()
      matches = tome.find(pattern)

      if matches.empty?
        raise CommandError, "No password found for #{pattern}."
      elsif matches.count == 1
        match = matches.first
        @out.puts "Password for #{match.first}:"
        @out.puts match.last
      else
        @out.puts "Multiple matches for #{pattern}:"
        matches.each { |key, password|
          @out.puts "#{key}: #{password}"
        }
      end
    end

    def delete(args)
      if args.length != 1
        raise CommandError, "Invalid arguments.\n\n#{$delete_usage}"
      end

      tome = tome_connect()

      # tome del bar.com
      # tome del foo@bar.com
      id = args[0]

      exists = !tome.get(id).nil?
      if exists
        confirmed = prompt_confirm("Are you sure you want to delete the password for #{id} (y/n)? ")
        if !confirmed
          raise CommandError, 'Aborted.'
        end
      end

      deleted = tome.delete(id)

      if deleted
        @out.puts "Deleted password for #{id}."
      else
        @out.puts "No password found for #{id}."
      end
    end

    def generate(args)
      if args.length != 1
        raise CommandError, "Invalid arguments.\n\n#{$generate_usage}"
      end
      
      tome = tome_create_connect()

      # tome gen bar.com
      # tome gen foo@bar.com
      id = args[0]
      password = generate_password()

      exists = !tome.get(id).nil?
      if exists
        confirm = prompt_confirm("A password already exists for #{id}. Overwrite (y/n)? ")
        if !confirm
          raise CommandError, 'Aborted.'
        end
      end

      created = tome.set(id, password)

      if created
        @out.puts "Generated password for #{id}."
      else
        @out.puts "Updated #{id} with the generated password."
      end
    end

    def copy(args)
      if args.length != 1
        raise CommandError, "Invalid arguments.\n\n#{$copy_usage}"
      end

      # tome cp bar.com
      # tome cp foo@bar.com
      pattern = args[0]

      tome = tome_connect()
      matches = tome.find(pattern)

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
          @out.puts "Password for #{match.first} copied to clipboard."
        else
          @err.puts "Failed to copy password for #{match.first} to clipboard."
        end
      end
    end

    def list(args)
      if !args.empty?
        raise CommandError, "Invalid arguments.\n\n#{$list_usage}"
      end

      tome = tome_connect()

      count = 0
      tome.each_password { |id, password|
        @out.puts "#{id}: #{password}"
        count += 1
      }

      if count == 0
        @out.puts 'No passwords stored.'
      end
    end

    def rename(args)
      if args.count != 2
        raise CommandError, "Invalid arguments.\n\n#{$rename_usage}"
      end

      tome = tome_connect()

      old_id = args[0]
      new_id = args[1]

      overwriting = !tome.get(new_id).nil?
      if overwriting
        confirm = prompt_confirm("A password already exists for #{new_id}. Overwrite (y/n)? ")
        if !confirm
          raise CommandError, 'Aborted.'
        end
      end

      renamed = tome.rename(old_id, new_id)
      
      if !renamed
        raise CommandError, "#{old_id} does not exist."
      else
        @out.puts "#{old_id} renamed to #{new_id}."
      end
    end

    def generate_password
      Passgen.generate(:length => 30, :symbols => true)
    end

    def prompt_password(prompt = 'Password')
      begin
        @err.print "#{prompt}: "
        password = input_password()

        if password.empty?
          @err.puts 'Password cannot be blank.'
          raise
        end

        @err.print "#{prompt} (verify): "
        verify = input_password()

        if verify != password
          @err.puts 'Passwords do not match.'
          raise
        end
      rescue
        retry
      end

      return password
    end

    def input_password
      @in.noecho { |stdin|
        password = stdin.gets.sub(/[\r\n]+\z/, '')
        @err.puts

        return password
      }
    end

    def prompt_confirm(prompt)
      begin
        @out.print prompt

        confirm = @in.gets.strip

        if confirm =~ /\Ay/i
          return true
        elsif confirm =~ /\An/i
          return false
        end
      rescue
        retry
      end
    end

    def tome_connect
      if !Tome.exists?(@tome_filename)
        raise CommandError, "Tome database does not exist. Use 'tome set' or 'tome generate' to create a password first."
      end

      begin
        @err.print 'Master password: '
        master_password = input_password()
        tome = Tome.new(@tome_filename, master_password)
      rescue MasterPasswordError
        @err.puts 'Incorrect master password.'
        retry
      end

      return tome
    end

    def tome_create_connect
      if !Tome.exists?(@tome_filename)
        @out.puts 'Creating tome database.'
        master_password = prompt_password('Master password')
        tome = Tome.create!(@tome_filename, master_password)
      else
        tome = tome_connect()
      end
    end
  end

# TODO: Complete these.
$usage = <<END
Usage:

    tome set [user@]<domain> [password]

        Create or update the password for an account.
        Example: tome set foo@gmail.com

    tome generate [user@]<domain>

        Generate a random password for an account.
        Example: tome generate reddit.com

    tome get <pattern>

        Show the passwords for all accounts matching the pattern.
        Example: tome get youtube

    tome copy <pattern>

        Copy the password for the account matching the pattern.
        Example: tome copy news.ycombinator.com

    tome list

        Show all stored accounts and passwords.
        Example: tome list

    tome delete [user@]<domain>

        Delete the password for an account.
        Example: tome delete foo@slashdot.org

    tome rename <old> <new>

        Rename the account information stored.
        Example: tome rename twitter.com foo@twitter.com

    tome help

        Shows help for a specific command.
        Example: tome help set
END

$help_usage = <<END
tome help

    Shows help for a specific command.

Usage:

    tome help
    tome help <command>

Examples:

    tome help
    tome help set
    tome help help (so meta)

Alias: help, --help, -h
END

$set_usage = <<END
tome set

    Create or update the password for an account. The user is optional.
    If you do not specify a password, you will be prompted for one.

Usage:

    tome set [user@]<domain> [password]

Examples:

    tome set gmail.com
    tome set gmail.com p4ssw0rd
    tome set foo@gmail.com
    tome set foo@gmail.com p4ssw0rd

Alias: set, s
END

$get_usage = <<END
tome get

    Show the passwords for all accounts matching the pattern.
    Matching is done with substring search. Wildcards are not supported.

Usage:

    tome get <pattern>

Examples:

    tome get gmail
    tome get foo@
    tome get foo@gmail.com

Alias: get, g, show
END

$delete_usage = <<END
tome delete

    Delete the password for an account.

Usage:

    tome delete [user@]<domain>

Examples:

    tome delete gmail.com
    tome delete foo@gmail.com

Alias: delete, del, d, remove, rm
END

$generate_usage = <<END
tome generate

    Generate a random password for an account. The user is optional.

Usage:

    tome generate [user@]<domain>

Examples:

    tome generate gmail.com
    tome generate foo@gmail.com

Alias: generate, gen
END

$copy_usage = <<END
tome copy

    Copy the password for the account matching the pattern.
    If more than one account matches the pattern, nothing happens.
    Matching is done with substring search. Wildcards are not supported.

Usage:

    tome copy <pattern>

Examples:

    tome copy gmail
    tome copy foo@
    tome copy foo@gmail.com

Alias: copy, cp
END

$list_usage = <<END
tome list

    Show all stored accounts and passwords.

Usage:

    tome list

Examples:

    tome list

Alias: list, ls
END

$rename_usage = <<END
tome rename

    Rename the account information stored.

Usage:

    tome rename <old> <new>

Examples:

    tome rename gmail.com foo@gmail.com
    tome rename foo@gmail.com bar@gmail.com

Alias: rename, ren, rn
END
end