// The host must call cs.EmbeddingStudio.Scheduler.me.start() from its own startup code,
// if do not accept activate in security settings  the "On Host Database Event" feature.
#DECLARE($event : Integer)
Case of 
	: ($event=On after host database startup:K74:4)
		
		cs:C1710.Scheduler.me.start()
		
	: ($event=On before host database exit:K74:5)
		
		cs:C1710.Scheduler.me.stop()
		
End case 
