//%attributes = {}
#DECLARE() : Integer

/*#17300
In project mode, if the “4D Embeddings Studio” component is loaded, in the “Design > Embeddings Studio...” menu, 
a “Scheduler Settings” item allows you to open the scheduler settings window alone, without the studio window.
*/

return _SCHEDULER_WIZARD  // same window, same "not running" warning first
