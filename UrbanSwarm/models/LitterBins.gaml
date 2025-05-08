/**
* Name: LitterBins
* Author: Dill_
* Description: 
* Tags: Tag1, Tag2, TagN
*/

model LitterBins 

import "./../models/UrbanSwarm_main.gaml"

//People generate approximately 1.31 kg per day
//Make an assumption that a certain percentage of that is dropped in public bins
//Standard trash bin sizes seem to be 20-32 gallons
//A gallon is roughly 3.78 kg of water

global {
	float trash_per_day <- 8.42;
}


species amenity parent:building {
	int id;
	bool fromGrid;
	float density <-0.0;
	rgb color;
	int x;
	int y;
	float size;
	
	float barrel_amount <- 0.0;
	
	int am_num <- 0;
	amenityBin a;
	
	init {
		create amenityBin number:1 with:(location:location);
		a <- amenityBin closest_to(self);
		ask a {
			self.location <- myself.location;
		}
	}
	
	//This one fills the trash bins up around it
	reflex fillTrashAround when: (option = 1){
		if (current_count[am_num] != 0) {
			float barrel_count <- 0.0;
			ask barrel at_distance(amenity_radius) {
				if (is_full() = false) {
					barrel_count <- barrel_count + 1;
				}
			}
			
			//Amount to be dropped in each nearby bin
			if (barrel_count != 0) {
				float trash_amount <- (float(current_count[am_num])*trash_multiplier)/barrel_count;
				ask barrel at_distance(amenity_radius) {
					if (total_trash + trash_amount < max_trash) {
						total_trash <- total_trash + trash_amount;
					}
				}
			}
		}
	}
	
	//This one creates it's own trash bin and fills it
	reflex fillOwnTrash when: (option = 2){
		if (current_count[am_num] != 0) {
			//write("People inside");
			float trash_amount <- (float(current_count[am_num])*trash_multiplier);
			if (barrel_amount + trash_amount < max_amenity_trash) {
				barrel_amount <- barrel_amount + trash_amount;
				ask a {
					do set_amount(myself.barrel_amount);
				}
			}
		}
	}
	
	action set_num(int num){
		am_num <- num;
	}
	
	aspect scaleGrid{
		if(fromGrid and id!=-2	){
			draw shape rotated_by -angle color: rgb(color.red, color.green, color.blue);
		}
	}
	
	aspect realistic {	
     	if(fromGrid and id!=-2){
			draw shape rotated_by -angle color: #gray depth:density*10;//rgb(color.red, color.green, color.blue) depth:density*10;
		}
	}

	aspect onScreen {		
		if(fromGrid){
			if(color!=nil){
			  draw shape rotated_by -angle color: rgb(color.red, color.green, color.blue,75);	
			}
		}
		else{
			if (toggle1 = 6){
			  draw circle(size) wireframe:true border:#white color: #white;
		      draw circle(size) color: rgb(255,255,255,125);	
			}
		}
	}
	
    aspect onTable {
		if(!fromGrid){
			if (toggle1 =  6){
			  draw circle(size) wireframe:true border:#white color: #white;
		      draw circle(size) color: rgb(255,255,255,125);	
			}
		}
	}

}

species Litter { 
	
	rgb circle_color <- rgb(0,255,0);
	int red_color<-0;
	int green_color<-255;
	
	float total_trash <- 0.0;
	
	action set_color(rgb new_color){
		circle_color <- new_color;
		
	}
		
	action update_color {
		red_color <- int(0.0 + (255.0/float(max_trash))*total_trash);
		green_color <- int(255.0 - (255.0/float(max_trash))*total_trash);
		circle_color <- rgb(red_color, green_color, 0);
	}
	
	bool is_full {
		if (total_trash >= max_trash) {
			return true;
		} else {
			return false;
		}
	}
	
	int get_trash {
		return int(total_trash);
	}
	
	reflex getPerson when:(is_full() = false){
		ask people at_distance(max_distance) {
			if (can_deposit_trash() = true and myself.total_trash + get_trash() < max_trash and trash_amount > 0) {
				myself.total_trash <- myself.total_trash + get_trash();
				//write("Trash dropped off");
				do reset();
				//write(myself.total_trash);
			}
		}
		do update_color();
	}
}

species amenityBin {
	
	rgb circle_color;
	float barrel_amount <- 0.0;
	
	aspect base {
		if (option = 1) {
			draw circle(amenity_radius) color: rgb(255,255,255) wireframe:true;
		} else if (option = 2) {
			do update_color;
			draw square(50 #m) color: circle_color;
		}
	}
	
	action update_color {
		int red_color <- int(0.0 + (255.0/float(max_amenity_trash))*barrel_amount);
		int green_color <- int(255.0 - (255.0/float(max_amenity_trash))*barrel_amount);
		circle_color <- rgb(red_color, 0, green_color);
	}
	
	action set_amount(float new_amount) {
		barrel_amount <- new_amount;
		do update_color;
	}
}

species holdingTrash {
	
	building living_place <- nil ;
	building working_place <- nil ;
	amenity eating_place<-nil;
	amenity dining_place<-nil;
	
	string objective ;
	point the_target <- nil;
	point current_target <- nil;
	
	string curMovingMode<-"wandering";	
	
	//Trash stuff
	bool canDropTrash<-true;
	bool has_trash<-false;
	
	//The last time when the trash was put in the bin
	int trashTime<-0;
	
	//This is the old version
	//The amount of trash that a person has (resets every time a person drops off trash)
	//float trash_amount<-rnd(min_trash_can_hold, max_trash_can_hold);
	float trash_amount <- 0.0;
	
	bool just_arrived<-true;
	
	//Amount I calculated per day
	float total_trash <- trash_per_day;
	
	//Number of times during the day that the person will drop trash
	float trash_drop_count <- 0.0;
	
	//An array of the times in which the person will drop trash
	list<bool> drop_at_time <- [false, false, false, false, false];
	
	//Caculates whether the person will drop trash while travelling or not
	action will_drop(float temp_prob){
		
		//If time doesn't effect it the person always has trash to drop
		if (does_time_effect = false) {
			has_trash<-true;
		} else {
			float random_num<-rnd(1.0);
			if (random_num <= temp_prob){
				has_trash<-true;
			} else{
				has_trash<-false;
			}
		}
	}
	
	action generate_trash {
		//Reset the variables
		drop_at_time <- [false, false, false, false, false];
		trash_drop_count <- 0.0;
		
		//Caculates at what times the person will drop trash. Also ensures that they drop trash at some point
		loop while:(trash_drop_count = 0) {
			drop_at_time[0] <- get_if_drop_trash(to_work_prob);
			drop_at_time[1] <- get_if_drop_trash(to_eat_prob);
			drop_at_time[2] <- get_if_drop_trash(after_eat_prob);
			drop_at_time[3] <- get_if_drop_trash(to_dinner_prob);
			drop_at_time[4] <- get_if_drop_trash(after_dinner_prob);
		}
		
	}
	
	bool get_if_drop_trash(float probability) {
		float r <- rnd(1.0);
		if (r <= probability) {
			trash_drop_count <- trash_drop_count + 1;
			return true;
		} else {
			return false;
		}
	}
	
	bool can_deposit_trash{
		if (time - trashTime > trashDelay) {
			if (curMovingMode = "travelling" or can_drop_inside = true){
				return true;
			} else {
				return false;
			}
		} else {
			return false;
		}
	}
	
	float get_trash{
		return trash_amount;
	}
	
	action reset{
		trashTime <- int(time);
		//Old version
		//trash_amount<-rnd(min_trash_can_hold, max_trash_can_hold);
		
		//New version
		trash_amount <- 0.0;
	}
	
	//This is for amenities
	action subtract_from_count {
		//write("Subtracting...");
		amenity test_place <- nil;
		if (objective = "eating") {
			test_place <- eating_place;
		} else if (objective = "dinning"){
			test_place <- dining_place;
		}
		
		int i <- 0;
		loop times: length(amenities){
			if (amenities[i] = test_place) {
				current_count[i] <- current_count[i] - 1;
			}
			i <- i + 1;
		}
	}
}

species people skills:[moving] parent:holdingTrash {
	rgb color <- #yellow ; 
	float initialSpeed;
	building living_place <- nil ;
	building working_place <- nil ;
	amenity eating_place<-nil;
	amenity dining_place<-nil;
	int time_to_work ;
	int time_to_lunch;
	int time_to_rework;
	int time_to_dinner;
	int time_to_sleep;
	string objective;
	string curMovingMode<-"wandering";	
	string scale;
	string usage; 
	point the_target <- nil ;
	point current_target <- nil;
	int degree;
	float radius;
	bool moveOnRoad<-true;
	bool fromTheGrid<-false;
	bool has_generated_trash <- false;
	
	init {
		do generate_trash;
	}
	
	action travellingMode{
		curMovingMode <- "travelling";
		speed <-initialSpeed;	
	}
	
    reflex updateTargetAndObjective {
		//Resets the amount of trash the person will generate for the day
		if (current_hour < time_to_work and has_generated_trash = false) {
			do generate_trash;
			has_generated_trash <- true;
		}
		
		//Need to make sure to update just arrived every time
		if(current_hour > time_to_work and current_hour < time_to_lunch  and objective = "resting"){
			objective <- "working" ;
			the_target <- any_location_in (working_place);
			current_target <- the_target;
			//do will_drop(to_work_prob);
			do travellingMode;
						
			just_arrived<-true;
			
			//If person is supposed to drop trash at this time, reset their amount
			if (drop_at_time[0] = true) {
				trash_amount <- total_trash/trash_drop_count;
			} else {
				trash_amount <- 0.0;
			}
			
			//Resets this value for the next day
			has_generated_trash <- false;
	    }
	
	    if(current_hour > time_to_lunch and current_hour < time_to_rework and objective = "working"){
			objective <- "eating" ;
			the_target <- any_location_in (eating_place);
			current_target <- the_target;
			//do will_drop(to_eat_prob); 
			do travellingMode;
			
			//do subtract_from_count();	
			just_arrived<-true;
			
			//If person is supposed to drop trash at this time, reset their amount
			if (drop_at_time[1] = true) {
				trash_amount <- total_trash/trash_drop_count;
			} else {
				trash_amount <- 0.0;
			}
			
	    } 
	
	    if (current_hour > time_to_rework and current_hour < time_to_dinner  and objective = "eating"){
			objective <- "reworking" ;
			the_target <- any_location_in (working_place);
			current_target <- the_target;
			//do will_drop(after_eat_prob);
			do travellingMode;
			
			do subtract_from_count();	
			just_arrived<-true;
			
			//If person is supposed to drop trash at this time, reset their amount
			if (drop_at_time[2] = true) {
				trash_amount <- total_trash/trash_drop_count;
			} else {
				trash_amount <- 0.0;
			}
	    } 
	    if(current_hour > time_to_dinner and current_hour < time_to_sleep  and objective = "reworking"){
			objective <- "dinning" ;
			the_target <- any_location_in (dining_place);
			current_target <- the_target;
			//do will_drop(to_dinner_prob);
			do travellingMode;
			
			//do subtract_from_count();	
			just_arrived<-true;
			
			//If person is supposed to drop trash at this time, reset their amount
			if (drop_at_time[3] = true) {
				trash_amount <- total_trash/trash_drop_count;
			} else {
				trash_amount <- 0.0;
			}
	    } 
	
	    if(current_hour > time_to_sleep and (current_hour < 24) and objective = "dinning"){
			objective <- "resting" ;
			the_target <- any_location_in (living_place);
			current_target <- the_target;
			//do will_drop(after_dinner_prob);
			do travellingMode;
			
			do subtract_from_count();	
			just_arrived<-true;
			
			//If person is supposed to drop trash at this time, reset their amount
			if (drop_at_time[4] = true) {
				trash_amount <- total_trash/trash_drop_count;
			} else {
				trash_amount <- 0.0;
			}
	    } 
		
	} 
	
	reflex move {
		//This deals with the amenity counter
	    if(moveOnRoad = true and the_target !=nil){
	      do goto target: the_target on: road_graph  ; 
	    }else{
	      do goto target: the_target;
	    }
		
		if (the_target = location) {
			if (just_arrived = true){	
				amenity test_place <- nil;
				if (objective = "eating") {
					test_place <- eating_place;
				} else if (objective = "dinning"){
					test_place <- dining_place;
				}
				
				int i <- 0;
				loop times: length(amenities){
					if (amenities[i] = test_place) {
						current_count[i] <- current_count[i] + 1;
						//write("Added");
						//write(current_count);
					}
					i <- i + 1;
				}
				just_arrived <- false;
			}
			the_target <- nil ;
			curMovingMode <- "wandering";
		}
		if(curMovingMode = "wandering"){
			do wander speed:(0.1) #km / #h;
		}
	}
		
	aspect scale{
	if(toggle1 !=1){
      if(!fromTheGrid){	
		  draw circle(8#m) color: color_map[scale];
		   
	  }else{
		  draw square(8#m) color: color_map[scale];  
	  }
	 } 
	}
	
	aspect scaleTable{
		if(toggle1 >4)
		{
		  draw circle(4#m) color: color_map[scale];	
		}
      
	}
	
	aspect trajectory{
		if(curMovingMode = "travelling"){
			draw circle(10#m) color: color_map[scale];
		}
		
	}
	
}



