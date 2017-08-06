require "erb" 

class CANSignal
    attr_accessor :name, :start_bit, :signal_size, :is_big_endian, :is_unsigned
    def initialize(name = "", start_bit = 0, signal_size = 0, is_big_endian = false, is_unsigned = false)
        @name, @start_bit, @signal_size = name, start_bit, signal_size
        @is_big_endian, @is_unsigned = is_big_endian, is_unsigned
    end
end

class CANMessage
    attr_accessor :name, :id, :signals

    def initialize(name = "", id = 0) 
        @name, @id = name, id
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
                 |item| item.to_s =~ %r!^DBC.+Matcher$! 
                }.map{ |item| method(item) }
            dbc_file.each_line do | line |
                parser_partterns.each { | parttern | parttern.call(line, file_descriptor) }
            end
        end
        return file_descriptor
    end

    def DBCSignalMatcher(line, file_des = nil)
        if line =~ %r%^\s*SG_\s+(\w+)\s+:\s+(\d+)\|(\d+)@(\d)(\+|-).*$% then
            signal = CANSignal.new($1, $2.to_i, $3.to_i, $4 == "0", $5 == "+")
            signal.start_bit = ChangeMotorolaOrderMSB2LSB($2.to_i, $3.to_i) if signal.is_big_endian
            if file_des != nil then
                file_des.messages.last.signals.push signal          
            end
            signal
        end 
    end

    def DBCMessageMatcher(line, file_des = nil)
        if line =~ %r|^BO_\s+(\d+)\s+(\w+)\s*:.*$| then
            msg = CANMessage.new($2, $1.to_i)
            if file_des != nil then
                file_des.messages.push msg
            end
            msg
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

#=begin
puts "Start Parsing!"
analyzer = CAN_DBC_Analzyer.new
can_database = analyzer.AnalyzeDBCFile("test.dbc")
puts "Start Generate Code"
template ="code_template.txt"
File.open( template ) { |fh| 
    erb_engine = ERB.new( fh.read ) 
    print erb_engine.result( binding )    
}
#=end

#print CAN_DBC_Analzyer.new.methods.collect! {|item| item if item.to_s =~ %r!^\w+Matcher$! }

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