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

    tome version

        Shows the version of tome.
        Example: tome version
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

Alias: set, s, add
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

Alias: delete, del, remove, rm
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