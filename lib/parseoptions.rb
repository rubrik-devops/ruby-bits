require 'optparse'
require 'optparse/time'
require 'ostruct'
require 'pp'

class OptparseExample

  CODES = %w[iso-2022-jp shift_jis euc-jp utf8 binary]
  CODE_ALIASES = { "jis" => "iso-2022-jp", "sjis" => "shift_jis" }

  #
  # Return a structure describing the options.
  #
  def self.parse(args)
    # The options specified on the command line will be collected in *options*.
    # We set default values here.
    options = OpenStruct.new

    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: rubrik.rb [options]"

      opts.separator ""
      opts.separator "Specific options:"

      # Optional argument with keyword completion.
      opts.on('-n', '--node [rubriknode]') do |node|
  		options[:n] = node;
  	  end
      opts.on('-p', '--password [rubrikpassword]') do |pass|
      options[:p] = pass;
      end
      opts.on('-u', '--username [rubrikuser]') do |user|
      options[:u] = user;
      end
      opts.on('-c', '--client [agentname]') do |c|
      options[:vm] = c;
      end
      opts.on('-g', '--get') do |g|
      options[:get] = g;
      end
      opts.on('-a', '--assure [parameter]') do |g|
      options[:assure] = g;
      end
      opts.on('--sla') do |g|
      options[:sla] = g;
      end
      opts.on('--file') do |g|
      options[:file] = g;
      end
      opts.separator ""
      opts.separator "Common options:"
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end

    end

    opt_parser.parse!(args)
    options
  end  # parse()

end  # class OptparseExample