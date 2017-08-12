# ver 0.9.0

require "erb" 

class CANSignal
    attr_accessor :name, :start_bit, :size, :is_big_endian, :is_unsigned
    attr_accessor :factor, :offset, :minimun, :maximun, :unit, :receivers

    def initialize(name = "", start_bit = 0, size = 0, is_big_endian = false, is_unsigned = false)
        @name, @start_bit, @size = name, start_bit, size
        @is_big_endian, @is_unsigned = is_big_endian, is_unsigned
        @factor, @offset, @minimun, @maximun = 0.0, 0.0, 0.0, 0.0
        @unit = ""
        @receivers = []  # store the names of receivers for this signal
    end
end

class CANMessage
    attr_accessor :name, :id, :signals, :size, :transmitter

    def initialize(name = "", id = 0, size = 0, transmitter = "") 
        @name, @id, @size, @transmitter = name, id, size, transmitter
        @signals = []
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

            #parser_partterns = [:DBCSignalMatcher, :DBCMessageMatcher]
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

             
=begin
            $6 =~ %r!\((-?\d+(\.\d+)?),(-?\d+(\.\d+)?)\)\s+\[(-?\d+(\.\d+)?)\s*\|\s*(-?\d+(\.\d+)?)\](.+)!
            signal.factor = $1.to_f
            signal.offset = $3.to_f
            signal.minimun = $5.to_f
            signal.maximun = $7.to_f

            $9 =~ %r!"(\w*)"\s+([\w,]*)!
            signal.unit = $1
            #signal.receivers = if $2 != "" then $2.split(",") else print $2 [] end  
            puts line
            puts $2
=end
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
=begin
    def DBCCommentMatcher(line, file_des = nil)
        puts "comment"
    end
=end
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

#=begin
puts "Start Parsing!"
analyzer = CAN_DBC_Analzyer.new
can_database = analyzer.AnalyzeDBCFile("A_eScooter_CAN_V0.32.dbc")
puts "Start Generate Code"
template ="code_template.txt"
file_name = "./il.h"
f = File.new(file_name, "w") 
File.open( template ) { |fh| 
    erb_engine = ERB.new( fh.read ) 
    #print erb_engine.result( binding )    
    f.print erb_engine.result( binding )   
}
#=end



=begin
template =" Service.java"
path = "/src/com/#{projectPath}/#{bean.package}/service"  
File.makedirs(path) unless FileTest.exist?(path) 
file = "#{path}/I#{bean.domain}Service.java"
f = File.new(file, "w") 
File.open( template ) { |fh| 
  erb_engine = ERB.new( fh.read ) 
  f.print erb_engine.result( binding )    
}
=end