// Only called when the host checked "Execute 'On Host Database Event' method of the components"
// in its Settings > Security. Otherwise the host must call cs.EmbeddingStudio.Scheduler.me.start()
// and .stop() from its own startup/shutdown code — see Scheduler.autoStart().
#DECLARE($event : Integer)
Case of 
	: ($event=On after host database startup:K74:4)
		
		cs:C1710.Scheduler.me.start()
		
	: ($event=On before host database exit:K74:5)
		
		cs:C1710.Scheduler.me.stop()
		
End case 
