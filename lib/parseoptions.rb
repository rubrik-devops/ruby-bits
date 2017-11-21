require 'optparse'
require 'optparse/time'
require 'ostruct'
class ParseOptions

  CODES = %w[iso-2022-jp shift_jis euc-jp utf8 binary]
  CODE_ALIASES = { "jis" => "iso-2022-jp", "sjis" => "shift_jis" }

  def self.parse(args)
  options = OpenStruct.new

  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: rubrik.rb [options]"

    opts.separator ""
    opts.separator "Specific options:"
    opts.on('-l', '--login', "Perform no operations but return authentication token") do |login|
      options[:login] = login;
    end
    opts.on('-c', '--client [name]', "Name of Virtual Machine to perform operation for") do |c|
      options[:vm] = c;
    end
    opts.on('-g', '--get',"Perform GET operation") do |g|
      options[:get] = g;
    end
    opts.on('-a', '--assure [string]',"String to set in SET operation (in case of --sla, it's the SLA Name)") do |g|
      options[:assure] = g;
    end
    opts.on('--sizerange low,high',Array,"Assure SLA based on VM VMDK sizes in Gigabyte (low,high)") do |g|
      options[:sr] = g;
    end
    opts.on('--os string,string',Array,"Assure SLA based on OS type") do |g|
      options[:os] = g;
    end
    opts.on('--dr', "Instant Recovery of --client") do |g|
      options[:dr] = g;
    end
    opts.on('--drcsv', "Instant Recovery of a csv of clients") do |g|
      options[:drcsv] = g;
    end
    opts.on('-s', "Startup VM before vMotion (Defaults to After)") do |g|
      options[:startbeforevmotion] = g;
    end
    opts.on('--short', "Only perform the source side tasks and ODB") do |g|
      options[:short] = g;
    end
    opts.on('-i', '--infile [string]', "Path to CSV file to run drcsv/odb against") do |g|
      options[:infile] = g;
    end
    opts.on('-t', '--threads [string]', "Number of simultaneous migrations") do |t|
      options[:threads] = t;
    end
    opts.on('--sla',"Perform and SLA Operation --get and --assure") do |g|
      options[:sla] = g;
    end
    opts.on('--sla [string]',"Perform and SLA Operation used with --odb and livemount/unmount") do |g|
      options[:sla] = g;
    end
    opts.on('--odb', "On demand backup of --client or --infile") do |g|
      options[:odb] = g;
    end
    opts.on('--livemount',"Perform livemount of SLA Domain") do |g|
      options[:livemount] = g;
    end
    opts.on('--unmount',"Perform umount of SLA Domain") do |g|
      options[:unmount] = g;
    end
    opts.on('--list', "Audit SLA configuration (used with --sla)") do |g|
      options[:list] = g;
    end
    opts.separator ""
    opts.separator "Report options:"
    opts.on('-r','--envision [string]', "Return Requested Envision Report Table Data") do |g|
      options[:envision] = g;
    end
    opts.on('--tag [string]', "Reference vmware tag (key by moref)") do |g|
      options[:tag] = g;
    end
    opts.on('--vmusage', "Return CSV of per-vm usage") do |g|
      options[:vmusage] = g;
    end
    opts.on('-o','--outfile [string]', "Specify Filename to Write out (STDOUT if not set)") do |g|
      options[:outfile] = g;
    end
    opts.separator ""
    opts.separator "Fileset options:"
    opts.on('--fsbackup', "Dump fileset configurations") do |g|
      options[:fsbackup] = g;
    end
    opts.on('--split', "Parse treesizes xml") do |g|
      options[:split] = g;
    end
    opts.on('--fsreport', "Generates CSV of useful fileset stats") do |g|
      options[:fsreport] = g;
    end
    opts.on('--sharename [string]', "Share to add Filesets to") do |g|
      options[:sharename] = g;
    end
    opts.on('--sharetype [string]', "SMB or NFS") do |g|
      options[:sharetype] = g;
    end
    opts.on('--hostname [string]', "Host to add Filesets to") do |g|
      options[:hostname] = g;
    end
    opts.on('--fsmake', "Generate Filesets") do |g|
      options[:filesetgen] = g;
    end
    opts.separator ""
    opts.separator "Metric options:"
    opts.on('--metric', "Return Requested Metric") do |g|
      options[:metric] = g;
    end
    opts.on('--storage', "Return storage capacity information") do |g|
      options[:storage] = g;
    end
    opts.on('--incoming', "Return the number of currently incoming snapshots") do |g|
      options[:incomingsnaps] = g;
    end
    opts.on('--runway', "Return the available runway in days") do |g|
      options[:runway] = g;
    end
    opts.on('--iostat [range]', "Return iostat information for range (30sec, 60min, etc)") do |g|
      options[:iostat] = g;
    end
    opts.on('--archivebw [range]', "Return archive bandwidth information for range (30sec, 60min, etc)") do |g|
      options[:archivebw] = g;
    end
    opts.on('--physicalingest [range]', "Return physical ingest bandwidth information for range (30sec, 60min, etc)") do |g|
      options[:physicalingest] = g;
    end
    opts.on('--localingest [range]', "Return local ingest bandwidth information for range (30sec, 60min, etc)") do |g|
      options[:localingest] = g;
    end
    opts.on('--snapshotingest [range]', "Return snapshot ingest bandwidth information for range (30sec, 60min, etc)") do |g|
      options[:snapshotingest] = g;
    end
    opts.on('-j', '--json', "Output in JSON if possible") do |g|
      options[:json] = g;
    end
    opts.on('-v', '--csv', "Output in CSV if possible") do |g|
      options[:csv] = g;
    end
    opts.separator ""
    opts.separator "Experimental options:"
    opts.on('--file', "Experimental - file search and recovery") do |g|
      options[:file] = g;
    end
    opts.on('--isilon [string]', "Experimental - Working with Isilon") do |g|
      options[:isilon] = g;
    end
    opts.on('--statnfb [int]', "Experimental") do |g|
      options[:statnfb] = g;
    end
    opts.on('--statndb [int]', "Experimental") do |g|
      options[:statndb] = g;
    end
    opts.on('--statnfa [int]', "Experimental") do |g|
      options[:statnfa] = g;
    end
    opts.on('--statnda [int]', "Experimental") do |g|
      options[:statnda] = g;
    end
    opts.on('--statnfc [int]', "Experimental") do |g|
      options[:statnfc] = g;
    end
    opts.on('--statndc [int]', "Experimental") do |g|
      options[:statndc] = g;
    end
    opts.separator ""
    opts.separator "Common options:"
    opts.on('-n', '--node [Address]', "Rubrik Cluster Address/FQDN") do |node|
      options[:n] = node;
    end
    opts.on('-u', '--username [username]',"Rubrik Cluster Username") do |user|
      options[:u] = user;
    end
    opts.on('-p', '--password [password]', "Rubrik Cluster Password") do |pass|
      options[:p] = pass;
    end
    opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
    end
  end
  opt_parser.parse!(args)
   options
  end
end
