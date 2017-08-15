# ver 0.9.0

require "erb" 

class CANSignal
    attr_accessor :name, :start_bit, :size, :is_big_endian, :is_unsigned
    attr_accessor :factor, :offset, :minimun, :maximun, :unit, :receivers, :attributes

    def initialize(name = "", start_bit = 0, size = 0, is_big_endian = false, is_unsigned = false)
        @name, @start_bit, @size = name, start_bit, size
        @is_big_endian, @is_unsigned = is_big_endian, is_unsigned
        @factor, @offset, @minimun, @maximun = 0.0, 0.0, 0.0, 0.0
        @unit = ""
        @receivers = []  # store the names of receivers for this signal
        @attributes = {}
    end
end

class CANMessage
    attr_accessor :name, :id, :signals, :size, :transmitter, :attributes

    def initialize(name = "", id = 0, size = 0, transmitter = "") 
        @name, @id, @size, @transmitter = name, id, size, transmitter
        @signals = []
        @attributes = {}
    end

end

class DBCFileDescriptor
    attr_accessor :messages

    def initialize() 
        @messages = []
    end
end

class CAN_DBC_Analzyer
    
    def AnalyzeDBCFile(file_name)
        file_descriptor = DBCFileDescriptor.new 
        
        File.open(file_name) do | dbc_file |
            parser_partterns = CAN_DBC_Analzyer.new.methods.select{
                 |item| item.to_s =~ /^DBC.+Matcher$/i 
                }.map { |item| method(item) }

            dbc_file.each_line do | line |
                parser_partterns.each { | parttern | parttern.call(line, file_descriptor) }
            end
        end
        return file_descriptor
    end

    def DBCSignalMatcher(line, file_des = nil)
        if line =~ %r%^\s*SG_\s+(\w+)\s+:\s+(\d+)\|(\d+)@(\d)(\+|-)(.+)$% then
            signal = CANSignal.new($1, $2.to_i, $3.to_i, $4 == "0", $5 == "+")
            signal.start_bit = ChangeMotorolaOrderMSB2LSB($2.to_i, $3.to_i) if signal.is_big_endian

            # [maximun|minmun] need to be updated. to support scientific notation
            if $6 =~ %r!\((-?\d+(\.\d+)?),(-?\d+(\.\d+)?)\)\s+\[.*\|.*\](.+)!
                signal.factor = $1.to_f
                signal.offset = $3.to_f
                signal.minimun = 0
                signal.maximun = 0

                if $5 =~ %r!"(.*)"\s+([\w,]*)! 
                    signal.unit = $1
                    signal.receivers = $2.split(",")
                end
            end

            if file_des != nil then
                file_des.messages.last.signals.push signal          
            end
            signal
        end 
    end

    def DBCMessageMatcher(line, file_des = nil)
        if line =~ %r|^BO_\s+(\d+)\s+(\w+)\s*:\s*(\d+)\s+(\w+)\s*$| then
            msg = CANMessage.new($2, $1.to_i, $3.to_i, $4)
            if file_des != nil then
                file_des.messages.push msg
            end
            msg
        end
    end

    def DBCAttributeValueMatcher(line, file_des = nil)
        #puts "In DBCAttributeValueMatcher"
        if line =~ %r|^BA_\s+"(\w+)"\s+(.*);$| then
            attr_name = $1
            #puts "Find a attribute #{attr_name}"
            #puts "$2 is |#{$2}|"
            case $2
            when /^BO_\s+(\d+)\s+(\d+)$/ then
                #puts "Find a attribute For message id: #{$1} and value is #{$2}"
                msg = file_des.messages.find {|msg| msg.id == $1.to_i }
                msg.attributes[attr_name.to_sym] = $2.to_i
            end
        end
    end

    private
    # because in DBC, if a signal is big_endian (Motorola order),
    # DBC file uses MSB as start bit.
    # otherwise, it uses LST as start bit.
    def ChangeMotorolaOrderMSB2LSB(start_bit, signal_size)
        while (signal_size -= 1) != 0 do
            start_bit += (start_bit % 8) == 0 ? 15 : -1
        end
        start_bit
    end
end


puts "Start Parsing!"
analyzer = CAN_DBC_Analzyer.new

if ARGV.size > 0 and ARGV[0] =~ /.*\.dbc/
    puts "Start Analyze DBC file #{ARGV[0]}"
    can_database = analyzer.AnalyzeDBCFile(ARGV[0])
    puts "Finished DBC file parsing"
    puts "Start Generate Code"
#=begin
    if ARGV.size == 2 and ARGV[1] =~ /.*\.erb/
        template_list = [ARGV[1]]
    else
        template_list = Dir["./*.erb"]
    end
    template_list.each do | temp_file |
        if temp_file =~ /(.*)\.erb/
            f = File.new($1, "w") 
            puts "Generating #{$1}"
            File.open(temp_file) { |fh| 
                erb_engine = ERB.new( fh.read ) 
                f.print erb_engine.result( binding )   
            }
        end
    end
#=end
end
