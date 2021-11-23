/**
 *  SwarmBot
 */

model swarmBot
import "./../models/UrbanSwarm_main.gaml"

global{
	//-----------------------------------------------------SwarmBot Parameters--------------------------------------------------
								
	float singlePheromoneMark <- 0.5;
	float evaporation <- 0.5;
	float exploratoryRate <- 0.8;
	float diffusion <- (1-exploratoryRate) * 0.5;	
	int additionalTrashBin <- 0;
	float maxTrash <- 121.0;
	int depositNum <- 3;
	int carriableTrashAmount <- 15;		
	int maxBatteryLife <- 720; // 2 h for PEV considering each cycle as 10 seconds in the real world
	float maxSpeedDist <- 2.5; // about 5.5  m/s for PEV (it can be changed accordingly to different robot specification)
	graph roadNetwork;	
	list<int> depositLocation;
    file imageRFID <- file('./../images/rfid-tag.png') ;
}


species pheromoneRoad {
	float pheromone;
	int lastUpdate;
	aspect pheromoneLevel {
		draw shape  color: rgb(125,125,150);
	}
	aspect base {
		draw shape color: #black;
	}
}

species deposit{
    int trash;
	int robots;
	aspect base {
			draw circle(25) color:#blue;		
	}
	aspect realistic{
		//draw cylinder(50,50)-cylinder(20,50) color:rgb(107,171,158);
		draw circle(50) color:rgb(107,171,158) empty:true;
	}
}

species trashBin {	
    float trash;
    bool decreaseTrashAmount;
    string type;
    rgb color;
    int group;  
    
    reflex updateTrash{
    	if(decreaseTrashAmount){
    		if (type='litter'){
	    		ask barrel closest_to self{
	    			self.total_trash<-myself.trash;
	    		}
	    	}else{
	    		ask amenityBin closest_to self{
	    			self.barrel_amount<-myself.trash;
	    		}
	    	}    
	    	decreaseTrashAmount<-false;	
    	}else{
	    	if (type='litter'){
	    		ask barrel closest_to self{
	    			myself.trash<-self.total_trash;
	    		}
	    	}else{
	    		ask amenityBin closest_to self{
	    			myself.trash<-self.barrel_amount;
	    		}
	    	}
    	}    	
    	
    }
	
	action update_color {
		int red_color <- int(0.0 + (255.0/float(maxTrash))*trash);
		int green_color <- int(255.0 - (255.0/float(maxTrash))*trash);
		color <- rgb(red_color,green_color,100);
	}
	
	aspect realistic3D {
		if(cycle<1){
			  draw cylinder(5+trash/100,10) - cylinder(2,10) color:color;
			}else{
				do update_color;
				draw cylinder(5,10) - cylinder(4,10) color:color;	
				if(trash>maxTrash){
					draw triangle(10) color:#black;
				}else{
					if(trash>carriableTrashAmount){
						draw triangle(10) color:#yellow;
					}
				}		
			}
	}
	aspect realistic {
		if(cycle<1){
			  draw circle(5+trash/100) color:color;
			}else{
				do update_color;
				draw circle(5+trash/100) color:color;	
				if(trash>maxTrash){
					draw square(2) color:#black;
				}else{
					if(trash>carriableTrashAmount){
						draw square(2) color:#yellow;
					}
				}		
			}
	}
}

species tagRFID {
	int id;
	bool checked;
	string type;
	
	list<float> pheromones;
	list<geometry> pheromonesToward;
	int lastUpdate;
	
	geometry towardDeposit;
	int distanceToDeposit;
	
	aspect realistic{
		draw circle(1+10*float(max(pheromones)/2)) color:rgb(107,171,158);
		//draw imageRFID size:5#m;
	}
}


species truck skills:[moving] {
	list<point> toClean;
	
	point target;
	path my_path; 
	point source;
	
	float speedDist;
	int timeToStart;
	int currentRoad;
	
	reflex searching when: (cycle > timeToStart){
		if (target != location) { 
		do wander on:road_graph;
		list<trashBin> closeTrashBin <- trashBin at_distance 50;
	
			ask closeTrashBin{ 	
						self.trash <- 0;	
						self.decreaseTrashAmount <- true;	
			}	
		}
	}
	
	aspect base {
		draw circle(10) color: rgb(225,225,255);
	}
}


species robot skills:[network, moving] {
	point target;
	path my_path; 
	point source;
	
	float pheromoneToDiffuse;
	float pheromoneMark; 
	
	int batteryLife;
	float speedDist; 
	
	int lastDistanceToDeposit;
	
	bool lowBattery;	
	bool carrying;
	

    aspect realistic {
		draw triangle(25)  color: rgb(25*1.1,25*1.6,200) rotate: heading + 90;
		if lowBattery{
			draw triangle(25) color: #darkred rotate: heading + 90;
		}
		if (carrying){
			draw triangle(25) color: rgb(175*1.1,175*1.6,200) rotate: heading + 90;
		}
	}
	
	aspect projector {
		draw circle(35) color:#lightblue rotate: heading + 90 empty:true;
		if lowBattery{
			draw circle(35) color:#red rotate: heading + 90;
		}
		if (carrying){
			draw circle(35) color:#yellow rotate: heading + 90;
		}
	}


	action updatePheromones{
		list<tagRFID>closeTag <- tagRFID at_distance 1;
		if not empty(closeTag) {
			ask closeTag closest_to(self){
			
			loop j from:0 to: (length(self.pheromonesToward)-1) {					
							
							self.pheromones[j] <- self.pheromones[j] + myself.pheromoneToDiffuse - (singlePheromoneMark * evaporation * (cycle - self.lastUpdate));					
							
							if (self.pheromones[j]<0.001){
								self.pheromones[j] <- 0;
							}	
							
							if(myself.carrying){								
								if (self.pheromonesToward[j]=myself.source){
									self.pheromones[j] <- self.pheromones[j] + myself.pheromoneMark ;									
								}
																	
							}
							//Saturation
							if (self.pheromones[j]>50*singlePheromoneMark){
									self.pheromones[j] <- 50*singlePheromoneMark;
								}
				}
				// Update tagRFID and pheromoneToDiffuse
				self.lastUpdate <- cycle;				
				myself.pheromoneToDiffuse <- max(self.pheromones)*diffusion;
			}
		
		}
		
		ask pheromoneRoad closest_to(self){	
			point p <- farthest_point_to (self , self.location);
			if (myself.location distance_to p < 1){			
				self.pheromone <- self.pheromone + myself.pheromoneToDiffuse - (singlePheromoneMark * evaporation * (cycle - self.lastUpdate));					
								
				if (self.pheromone<0.01){
					self.pheromone <- 0.0;
				}	
								
				if(myself.carrying){
						self.pheromone <- self.pheromone + myself.pheromoneMark ;
				}	
				self.lastUpdate <- cycle;				
			}							
		}
	}
	
	reflex searching when: (!carrying and !lowBattery){		
		my_path <- self goto (on:roadNetwork, target:target, speed:speedDist, return_path: true);		
		
		if (target != location) { 
			//collision avoidance time
				do updatePheromones;
			//If there is enough battery and trash, carry it!
		 	list<trashBin> closeTrashBin <- trashBin at_distance 50;
		 	if (not empty(closeTrashBin)) {
			//ask closeTrashBin closest_to(self) {		
			ask closeTrashBin with_max_of(each.trash){		
				
				if (self.trash > carriableTrashAmount){
					if(myself.batteryLife > myself.lastDistanceToDeposit/myself.speedDist){
						self.trash <- self.trash - carriableTrashAmount;	
						self.decreaseTrashAmount<-true;
						myself.pheromoneMark <- (singlePheromoneMark * int(self.trash/carriableTrashAmount));		
						myself.carrying <- true;
					}
					else{
						myself.lowBattery <- true;
					}
				}	
			}
			
			}
		}
		else{				
			ask tagRFID closest_to(self){
				myself.lastDistanceToDeposit <- self.distanceToDeposit;
				
				// If enough batteryLife follow the pheromone 
				if(myself.batteryLife < myself.lastDistanceToDeposit/myself.speedDist){ 
					myself.lowBattery <- true;
				}
				else{
				
					list<float> edgesPheromones <-self.pheromones;
					
					if(mean(edgesPheromones)=0){ 
						// No pheromones,choose a random direction
						myself.target <- point(self.pheromonesToward[rnd(length(self.pheromonesToward)-1)]);
					}
					else{  
						// Follow strongest pheromone trail (with exploratoryRate Probbility if the last path has the strongest pheromone)					
						float maxPheromone <- max(edgesPheromones);	
						//*
						loop j from:0 to:(length(self.pheromonesToward)-1) {					
							if (maxPheromone = edgesPheromones[j]) and (myself.source = point(self.pheromonesToward[j])){
								edgesPheromones[j]<- flip(exploratoryRate)? edgesPheromones[j] : 0.0;					
							}											
						}
						maxPheromone <- max(edgesPheromones);	

								
						// Follow strongest pheromone trail (with exploratoryRate Probability in any case)			
						loop j from:0 to:(length(self.pheromonesToward)-1) {			
							if (maxPheromone = edgesPheromones[j]){
								if flip(exploratoryRate){	
									myself.target <- point(self.pheromonesToward[j]);
									break;	
									}	
									else {
										myself.target <- point(self.pheromonesToward[rnd(length(self.pheromonesToward)-1)]);
										break;
									}			
								}											
							}
						}				
					}
				}
				do updatePheromones;
				source <- location;
			}
	}

	reflex depositing when: (carrying or lowBattery){
		my_path <- self goto (on:roadNetwork, target:target, speed:speedDist, return_path: true);
		
		if (target != location) {
			//collision avoidance time
			do updatePheromones;
		}		
		else{				
			ask tagRFID closest_to(self) {
				// Update direction and distance from closest Deposit
				myself.target <- point(self.towardDeposit);
				myself.lastDistanceToDeposit <- self.distanceToDeposit;
				
				
			}
			do updatePheromones;
			source <- location;
			// Recover wandering status, delete pheromones over Deposits
			loop i from: 0 to: length(depositLocation) - 1 {
					if(location = point(roadNetwork.vertices[depositLocation[i]])){
						ask tagRFID closest_to(self){
							self.pheromones <- [0.0,0.0,0.0,0.0,0.0];
						}
						
						ask deposit closest_to(self){
							if(myself.carrying){
								self.trash <- self.trash + carriableTrashAmount;
								myself.carrying <- false;
								myself.pheromoneMark <- 0.0;
							}
							if(myself.lowBattery){
								self.robots <- self.robots + 1;
								myself.lowBattery <- false;
								myself.batteryLife <- maxBatteryLife;
								// Add randomicity and diffusion when the battery is recharged
								myself.target <- point(one_of(deposit));
							}							
						}
					}
			}
		}
	}
	
		reflex send_udp_info {
		do send to: "epuck" contents: last(name + 20) + ',' + self.heading + ',' + self.speed;
	}
	
		reflex fetch when:has_more_message() {
		loop while:has_more_message()
		{
			message s <- fetch_message();
			write string(s.contents);
		}
		}	
}

