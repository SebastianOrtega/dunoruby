=begin rdoc

=Alien Ruby RFID Library Examples
==ex_automode.rb

The reader supports a simple state machine to control when it reads tags and 
reports data to hosts. When "automode" is "on", the state machine is active. 
Using Automode is the best way to ensure reliable, low-latency tag reads. 
This example shows how to set up automode for continuous reading for three seconds.

Copyright 2014, Alien Technology Corporation. All rights reserved.

=end

# add the default relative library location to the search path
$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'alienreader'
require 'alienconfig'
require 'net/http'
require 'json'

begin
# grab various parameters out of a configuration file
	config = AlienConfig.new('config.ini')

# change "reader_address" in the config.dat file to the IP address of your reader.
	ipaddress = config.fetch('reader_address', 'localhost')
	puts ipaddress
#Configura POST
	port = 8000
	host = "192.168.0.188"
	path = "/"

	body = {}
	req = Net::HTTP::Post.new(path, initheader = { 'Content-Type' => 'application/json'})

	noTags="(No Tags)"

# create our reader 
	r = AlienReader.new

	if r.open(ipaddress)    
		puts '----------------------------------'
		puts "Connected to #{r.readername}"	
		puts "Automode is currently #{r.automode}"
		r.taglistcustomformat = "%k, ${TIME1},${COUNT},${RSSI},${NAME},${RX}"
   		r.taglistformat = "custom"
		#r.automodereset # reset to the default automode settings (no triggers, no delays, etc.)
		r.automode = 'on'
			
		loop do  # este primer loop es para manejar el error en caso de falla en la conexion tcp
		
			loop do

				tiempo=0
				dig_in = 0
				while tiempo<40 && dig_in<1 do    #210 para 28 segs   Control de debouncing 
					dig_in = r.gpio.to_i
					debouncing=0
					if dig_in > 0 
						debouncing=1
					end
					sleep 0.1
					dig_in = r.gpio.to_i
					if (dig_in)>0 
						debouncing=debouncing+1
					end
					sleep 0.1
					dig_in = r.gpio.to_i
					if (dig_in)>0
						debouncing=debouncing+1
					end
					sleep 0.1
					dig_in = r.gpio.to_i
					if (dig_in)>0
						debouncing=debouncing+1
					end
					if debouncing!=4
						dig_in=0
					end 
					


					tiempo = tiempo+1
					puts "#{tiempo} #{debouncing} #{dig_in}"
				end
				
				puts "Digital input : #{dig_in}"
				tagString=r.taglist
				if !tagString.include? noTags
					
					nuevo = tagString.split(/[\n\r]+/)
					datoSeparado= nuevo.map {
						|n| n.split(/[,]+/)

					}

					puts datoSeparado
					puts 'Tags Found:'+nuevo.length().to_s
					body = {'Equipo'=>r.readername,'Entrada' => dig_in, "numerotags"=>nuevo.length().to_s, "datos"=>datoSeparado}	
					req.body = JSON[body]
					response = Net::HTTP.new(host, port).start {|http| http.request(req) }
					if response.code!="200"
						puts response.code
					end		


					

				else
					puts "no hay tags"
				end
			
				
			end rescue
			puts $!
		end


		puts '...Done!'
		puts 'Tags Found:'
		puts r.taglist
		r.automode = 'off'
		puts '----------------------------------'



		
	# be nice. Close the connection to the reader.
		r.close
	end
rescue SocketError => ex
	#puts ex.inspect
	puts $!
	retry
end
