require 'uri'
require 'mixlib/shellout'

module Berkshelf
  # @author Jamie Winsor <jamie@vialstudios.com>
  class Git
    GIT_REGEXP = URI.regexp(%w{ https git }).freeze
    SSH_REGEXP = /(.+)@(.+):(.+)\.git/.freeze
    HAS_QUOTE_RE = %r{\"}.freeze
    HAS_SPACE_RE = %r{\s}.freeze

    class << self
      # @overload git(commands)
      #   Shellout to the Git executable on your system with the given commands.
      #
      #   @param [Array<String>]
      #
      #   @return [String]
      #     the output of the execution of the Git command
      def git(*command)
        command.unshift(git_cmd)
        command_str = command.map { |p| quote_cmd_arg(p) }.join(' ')
        cmd = Mixlib::ShellOut.new(command_str)
        cmd.run_command

        unless cmd.exitstatus == 0
          raise GitError.new(cmd.stderr)
        end

        cmd.stdout.chomp
      end

      # Clone a remote Git repository to disk
      #
      # @param [String] uri
      #   a Git URI to clone
      # @param [#to_s] destination
      #   a local path on disk to clone to
      #
      # @return [String]
      #   the destination the URI was cloned to
      def clone(uri, destination = Dir.mktmpdir)
        git("clone", uri, destination.to_s)

        destination
      end

      # Checkout the given reference in the given repository
      #
      # @param [String] repo_path
      #   path to a Git repo on disk
      # @param [String] ref
      #   reference to checkout
      def checkout(repo_path, ref)
        Dir.chdir repo_path do
          git("checkout", "-q", ref)
        end
      end

      # @param [Strin] repo_path
      def rev_parse(repo_path)
        Dir.chdir repo_path do
          git("rev-parse", "HEAD")
        end
      end

      # Return an absolute path to the Git executable on your system
      #
      # @return [String]
      #   absolute path to git executable
      #
      # @raise [GitNotFound] if executable is not found in system path
      def find_git
        git_path = nil
        ENV["PATH"].split(File::PATH_SEPARATOR).each do |path|
          git_path = detect_git_path(path)
          break if git_path
        end

        unless git_path
          raise GitNotFound
        end

        return git_path
      end

      # Determines if the given URI is a valid Git URI. A valid Git URI is a string
      # containing the location of a Git repository by either the Git protocol,
      # SSH protocol, or HTTPS protocol.
      #
      # @example Valid Git protocol URI
      #   "git://github.com/reset/thor-foodcritic.git"
      # @example Valid HTTPS URI
      #   "https://github.com/reset/solve.git"
      # @example Valid SSH protocol URI
      #   "git@github.com:reset/solve.git"
      #
      # @param [String] uri
      #
      # @return [Boolean]
      def validate_uri(uri)
        unless uri.is_a?(String)
          return false
        end

        unless uri.slice(SSH_REGEXP).nil?
          return true
        end

        unless uri.slice(GIT_REGEXP).nil?
          return true
        end

        false
      end

      # @raise [InvalidGitURI] if the given object is not a String containing a valid Git URI
      #
      # @see validate_uri
      def validate_uri!(uri)
        unless validate_uri(uri)
          raise InvalidGitURI.new(uri)
        end

        true
      end

      private

        def git_cmd
          @git_cmd ||= find_git
        end

        def quote_cmd_arg(arg)
          return arg if HAS_QUOTE_RE.match(arg)
          return arg unless HAS_SPACE_RE.match(arg)
          "\"#{arg}\""
        end

        def detect_git_path(base_dir)
          %w{ git git.exe git.cmd }.each do |git_cmd|
            potential_path = File.join(base_dir, git_cmd)
            if File.executable?(potential_path)
              return potential_path
            end
          end
          nil
        end
    end
  end
end
