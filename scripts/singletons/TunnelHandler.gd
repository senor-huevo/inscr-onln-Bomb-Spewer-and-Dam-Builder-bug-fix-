extends Node

var pid = -1

signal recieved_output(line)
signal process_ended()

func start_tunnel():
	print("Starting tunnel")
	
	# These commands for windows systems
	if OS.get_name() == "Windows":
		print("Executing windows commands")
		OS.execute ("cmd.exe", ["/c", "TYPE NUL > lhrlog.txt"], true)
		pid = OS.execute ("cmd.exe", ["/c", "ssh -R 80:localhost:10567 nokey@localhost.run > lhrlog.txt"], false)
	# These commands for OSX / Linux systems
	else:
		OS.execute ("bash", ["-c", "echo \"\" > lhrlog.txt"], true)
		pid = OS.execute ("bash", ["-c", "ssh -R 80:localhost:10567 nokey@localhost.run > lhrlog.txt"], false)
	
	var fiel = File.new()
	
	var current_size = 0
	
	print("Opening lhrlog.txt with err code: ", fiel.open("lhrlog.txt", File.READ))
	while OS.is_process_running(pid):
		yield(get_tree().create_timer(1), "timeout")
		
		if fiel.get_len() > current_size:
			print(current_size, " : ", fiel.get_len())
			print("got tunnel output: ", fiel.get_as_text().right(current_size))
			
			emit_signal("recieved_output", fiel.get_as_text().right(current_size))
			
			current_size = fiel.get_len()
	
	print("Process died")
	emit_signal("process_ended")
		
func kill_tunnel():
#	return
	
	if pid > 0 and OS.is_process_running(pid):
		print("Killing tunnel with pid ", pid)
		if OS.get_name() == "Windows":
			
			# As windows PID is arbitrary, need to do this
			OS.execute("taskkill", ["/IM", "ssh.exe", "/F"])
			
		else:
			# Because of how pipes work, we need to do this (on linux at least)
			print("Error code: ", OS.kill(pid+1))

func _exit_tree():
	kill_tunnel()
