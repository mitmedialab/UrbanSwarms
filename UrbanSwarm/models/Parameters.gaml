/***
* Name: Parameters file
***/

model Parameters

/* Insert your model definition here */
global{
	//-------------------------------------------------------------My Parameters----------------------------------------------------------------------------------
	
	bool truckOrRobots <- true parameter: "Truck or Robot: " category: "Initial"; //0= truck, 1 =robot
	int robotNum <- 1 min: 1 max: 100 parameter: "Nb Vehicle:" category: "Initial";		
	
	//Makes the cycles longer
	float minimum_cycle_duration <- 0.02;
	
	//Cylce length agringard is the github I need to add
	float step <- 10 #sec;
	
	//Time offset for when to start the day
	int time_offset <- 6 parameter: "Start Time:" category: "Initial";
	
	//Whether or not to stop the simulation after a certain number of days
	bool stop_simulation <- true parameter: "Stop Simulation: " category: "Initial";
	
	//The number of days to stop the simulation after
	int stop_sim_day <- 1 parameter: "The number of days to stop the simulation after: " category: "Initial";
	
	//Scale by which the population is
	int pop_scale <- 10 parameter: "Population Control (Higher # => Less people):" category: "People";
	
	//Furthest a person can be away but still put trash in a bin
	float max_distance <- 30.0#m min:1.0 #m max: 75.0 #m parameter: "Barrel Range:" category: "Litter Barrels";
	
	//The radius that amenities generate barrel trash
	float amenity_radius <- 100.0 #m parameter: "Amenity Trash Radius:" category: "Amenity";
	
	//The delay between when they can put trash in the bin
	int trashDelay<-1000 min: 1 max: 10000 parameter: "Trash Time Delay:" category: "Litter Barrels";
	
	//Minimum trash that a person can hold when dropping
	//float min_trash_can_hold<-0.5 parameter: "Minimum Trash Person can Hold:" category: "Litter Barrels";
	
	//Max amount of trash a person could drop at once
	//float max_trash_can_hold<-1.0 parameter: "Max Trash Person can Hold:" category: "Litter Barrels";
	
	//Max amount of trash put in the bin
	float max_trash<-121.133 parameter: "Max Trash (per bin):" category: "Litter Barrels";
	
	//Max amount of trash in each amenity
	float max_amenity_trash<-121.0 parameter: "Max Trash (per amenity):" category: "Amenity";
	
	//Wether or not a person can drop off trash when they aren't travelling
	bool can_drop_inside<-false parameter: "Can drop while not travelling:" category: "Litter Barrels";
	
	//Whether or not the time of day effects that probability of them dropping off
	bool does_time_effect<-true parameter: "Does time of travel affect (probabilities):" category: "Probability";
	
	//Multiplier for how much trash gets dropped
	float trash_multiplier <- 0.0001 parameter: "Trash Mult:" category: "Amenity";
	
	//Changes how trash is generated in amenities
	int option <- 2 parameter: "Amenity Generation Type (1 or 2): " category: "Amenity";
	
	//trace of the display
	int traceLength<-5  min: 1 max: 100 parameter: "trace value:" category: "Visualization";
	
}

