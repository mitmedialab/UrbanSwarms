/***
* Name: Parameters
* Author: Arno
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model Parameters

/* Insert your model definition here */
global{
	//-------------------------------------------------------------My Parameters----------------------------------------------------------------------------------
	
	bool truckOrRobots <- true; //0= truck, 1 =robot
	int robotNum <- 1;		
	//Makes the cycles longer
	float minimum_cycle_duration <- 1.0 #sec;
	//Time offset for when to start the day
	int time_offset <- 6;
	
	//Whether or not to stop the simulation after a certain number of days
	bool stop_simulation <- true;
	
	//The number of days to stop the simulation after
	int stop_sim_day <- 1;
	
	//Scale by which the population is
	int pop_scale <- 1;
	
	//Furthest a person can be away but still put trash in a bin
	float max_distance <- 30.0#m;
	
	//The radius that amenities generate barrel trash
	float amenity_radius <- 100.0 #m;
	
	//The delay between when they can put trash in the bin
	int trashDelay<-1000;
	
	//Minimum trash that a person can hold when dropping
	//float min_trash_can_hold<-0.5 parameter: "Minimum Trash Person can Hold:" category: "Litter Barrels";
	
	//Max amount of trash a person could drop at once
	//float max_trash_can_hold<-1.0 parameter: "Max Trash Person can Hold:" category: "Litter Barrels";
	
	//Max amount of trash put in the bin
	float max_trash<-121.133;
	
	//Max amount of trash in each amenity
	float max_amenity_trash<-121.0;
	
	//Wether or not a person can drop off trash when they aren't travelling
	bool can_drop_inside<-false;
	
	//Whether or not the time of day effects that probability of them dropping off
	bool does_time_effect<-true;
	
	//Multiplier for how much trash gets dropped
	float trash_multiplier <- 0.0001;
	
	//Changes how trash is generated in amenities
	int option <- 2;
	
	//trace of the display
	int traceLength<-5;
	
}

