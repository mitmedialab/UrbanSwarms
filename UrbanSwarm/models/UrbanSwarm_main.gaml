/**
* Name: UrbanSwarms
*/

model UrbanSwarms

import "./../models/Parameters.gaml"
import "./../models/LitterBins.gaml"
import "./../models/swarmBot.gaml"

global {
	
    //kml kml_export;
    date starting_date <- #now;
	//---------------------------------------------------------Performance Measures-----------------------------------------------------------------------------
	int trashPerTime;
	int fullTrashBin;
	int randomID;
	//-------------------------------------------------------------------Necessary Variables--------------------------------------------------------------------------------------------------
	
	//Whether or not the simulation has stopped
	bool is_sim_stopped <- false;
	
	//Popularity of each place
	list<float> am_lunch_pop <- [0];
	list<float> am_dinner_pop <- [0];
	
	list<amenity> amenities <- [];
	
	list<int> current_count <- [0];
	
	//All of the different times and different probabilities during those times
	float to_work_prob <- 0.4 min:0.0 max: 1.0 parameter: "To Work:" category: "Probability";
	float to_eat_prob <- 0.1 min:0.0 max: 1.0 parameter: "To Eat:" category: "Probability";
	float after_eat_prob <- 0.75 min:0.0 max: 1.0 parameter: "After Food:" category: "Probability";
	float to_dinner_prob <- 0.1 min:0.0 max: 1.0 parameter: "To Dinner:" category: "Probability";
	float after_dinner_prob <- 0.6 min:0.0 max: 1.0 parameter: "After Dinner:" category: "Probability";
	
	string cityGISFolder <- "./../includes/City/volpe";
	
	// GIS FILES //
	file litter_shapefile <- file(cityGISFolder+"/UrbanSwarm/DPW_LitterBarrels.shp");
	file bound_shapefile <- file(cityGISFolder+"/Bounds.shp");
	file buildings_shapefile <- file(cityGISFolder+"/Buildings.shp");
	file roads_shapefile <- file(cityGISFolder+"/Roads.shp");
	file amenities_shapefile  <- file(cityGISFolder+"/amenities.shp");
	file table_bound_shapefile <- file(cityGISFolder+"/table_bounds.shp");
	file imageRaster <- file('./../images/gama_black.png') ;
	geometry shape <- envelope(bound_shapefile);
	graph road_graph;
	graph<people, people> interaction_graph;
	
	//ONLINE PARAMETERS
	bool drawInteraction <- false parameter: "Draw Interaction:" category: "Interaction";
	int distance parameter: 'distance ' category: "Interaction" min: 1 max:200 <- 100;
	int refresh <- 50 min: 1 max:1000 parameter: "Refresh rate (cycle):" category: "Grid";
	bool dynamicGrid <-false parameter: "Update Grid:" category: "Grid";
	bool dynamicPop <-false parameter: "Dynamic Population:" category: "Population";
	int refreshPop <- 100 min: 1 max:1000 parameter: "Pop Refresh rate (cycle):" category: "Population";
	
	//INIT PARAMETERS
	bool cityMatrix <-false;
	bool onlineGrid <-true; // In case cityIOServer is not working or if no internet connection
	bool realAmenity <-true;
	
	/////////// CITYMATRIX   //////////////
	map<string, unknown> cityMatrixData;
	list<map<string, int>> cityMatrixCell;
	list<float> density_array;
	list<float> current_density_array;
	int toggle1;
	map<int,list> citymatrix_map_settings<- [-1::["Green","Green"],0::["R","L"],1::["R","M"],2::["R","S"],3::["O","L"],4::["O","M"],5::["O","S"],6::["A","Road"],7::["A","Plaza"],8::["Pa","Park"],9::["P","Parking"]];	
	map<string,rgb> color_map<- ["R"::rgb(43,43,43), "O"::rgb(27,27,27),"S"::#gamablue, "M"::#gamaorange, "L"::#gamared, "Green"::#green, "Plaza"::#white, "Road"::#black,"Park"::#black,"Parking"::rgb(50,50,50)]; 
	list scale_string<- ["S", "M", "L"];
	list usage_string<- ["R", "O"]; 
	list density_map<- [89,55,15,30,18,5]; //Use for Volpe Site (Could be change for each city)
	
	//Just add number to this to start it at a different time
	int current_hour update: time_offset + (time / #hour) mod 24  ;
	int current_day<-0;
	int min_work_start <- 4;
	int max_work_start <- 10;
	int min_lunch_start <- 11;
	int max_lunch_start <- 13;
	int min_rework_start <- 14;
	int max_rework_start <- 16;
	int min_dinner_start <- 18;
	int max_dinner_start <- 20;
	int min_work_end <- 21; 
	int max_work_end <- 22; 
	float min_speed <- 4 #km / #h;
	float max_speed <- 6 #km / #h; 
	float angle<-0.0;
	point center;
	float brickSize;
	string cityIOUrl;
	
	int max_spawn_x <- world.shape.width;
	int max_spawn_y <- world.shape.height;
	
	int first <- 1;
	
	//------------------------------------------------------------------------Important Functions-----------------------------------------------------
	
	list<barrel> getVolpeBarrels{
		list<barrel> barrels <- [];
		ask barrel{
			int x <- self.location.x;
			int y <- self.location.y;
			if (x > 0) {
				if (y > 0) {
					barrels <- barrels + [self];
				} else {
					do kill;
				}
			} else {
				do kill;
			}
		}
		return barrels;
	}
	
	action assignPopularity{
		amenities <- getAmenities();
		
		loop times: length(amenities){
			am_lunch_pop <- am_lunch_pop + [0];
			am_dinner_pop <- am_dinner_pop + [0];
			current_count <- current_count + [0];
		}
		ask people{
			int i <- 0;
			loop times: length(amenities){
				if (amenities[i] = eating_place) {
					am_lunch_pop[i] <- am_lunch_pop[i] + 1;
				}
				if (amenities[i] = dining_place) {
					am_dinner_pop[i] <- am_dinner_pop[i] + 1;
				}
				i <- i + 1;
			}
			
		}
		write(am_lunch_pop);
	}
	
	list<amenity> getAmenities{
		list<amenity> am <- [];
		int i <- 0;
		ask amenity{
			am <- am + [self];
			do set_num(i);
			i <- i + 1;
		}
		return am;
	}
	
	float get_distance(float x1, float y1, float x2, float y2){
		return sqrt((x1 - x2)*(x1 - x2) + (y1 - y2)*(y1 - y2));
	}
	
	//-------------------------------------Species Creation-----------------------------------------------------------------------------------------------------------------------
	
	init {
		//---------------------------------------------------PERFORMANCE-----------------------------------------------
		trashPerTime <- 0;
		fullTrashBin <- 0;
		randomID <- rnd (10000);
		//This just creates them randomly with random s
		create barrel from: litter_shapefile;
		create table from: table_bound_shapefile;
		create building from: buildings_shapefile with: [usage::string(read ("Usage")),scale::string(read ("Scale")),nbFloors::1+float(read ("Floors"))]{
			area <-shape.area;
			perimeter<-shape.perimeter;
			depth<-50+rnd(50);
		}
		create road from: roads_shapefile ;
		road_graph <- as_edge_graph(road);
		
		
		if(realAmenity = true){
          create amenity from: amenities_shapefile{
		    scale <- scale_string[rnd(2)];	
		    fromGrid<-false;
		    size<-10+rnd(20);
		  }		
        }
       	

        angle <- -9.74;
	    center <-{1007,632};
	    brickSize <- 21.3;
		cityIOUrl <- "https://cityio.media.mit.edu/api/table/citymatrix_volpe";	

	    if(cityMatrix = true){
	   		do initGrid;
	    }	
	    write " width: " + world.shape.width + " height: " + world.shape.height;
	    
	    //Removes all of the barrels outside the boundaries
	    do getVolpeBarrels();
	    	
		// ----------------------------The Roads (459 and 462 are broken)-------------------------------------
		create pheromoneRoad from: roads_shapefile{
			pheromone <- 0.0;
		}
			
		ask pheromoneRoad[459]{
			do die;
		}
		ask pheromoneRoad[462]{
			do die;
		}	
					
		// ---------------------------------------The Road Network----------------------------------------------
		roadNetwork <- as_edge_graph(pheromoneRoad) ;					
		
		// Next move to the shortest path between each point in the graph
		matrix allPairs <- all_pairs_shortest_path (roadNetwork);	
		
		// --------------------------------------------Trash Bins--------------------------------------------
		create trashBin from: 5 first litter_shapefile{ 	
			trash <- 0.0;
			type <- "litter";
			decreaseTrashAmount<-false;
			shape<-circle(10);							
		}
		
//		loop i from: 0 to: length(amenityBin)-1{
//			create trashBin{
//				location <- amenityBin[i].location;
//				trash <- 0.0;
//				type <- "amenityBin";
//				decreaseTrashAmount<-false;
//			}
//		}

		// -------------------------------------Location of the Deposits----------------------------------------
		//K-Means
		//Create a list of list containing for each trashBin agent a list composed of its x and y values
			list<list> instances <- trashBin collect ([each.location.x, each.location.y]);
			
			//from the previous list, create k groups  with the Kmeans algorithm (https://en.wikipedia.org/wiki/K-means_clustering)
			list<list<int>> clusters_kmeans <- list<list<int>>(kmeans(instances, depositNum));
			
			//from clustered trashBin to centroids locations
			int groupIndex <- 0;
			list<point> coordinatesCentroids <- [];
			loop cluster over: clusters_kmeans {
				groupIndex <- groupIndex + 1;
					list<point> coordinatesTrashBin <- [];
					rgb col <- rnd_color(255);
					loop TB over: cluster {
						add trashBin[TB].location to: coordinatesTrashBin; 
						ask trashBin[TB]{
							color <- col;
							group <- groupIndex;
						}
					}
				add mean(coordinatesTrashBin) to: coordinatesCentroids;
			}
			
			//from centroids locations to closest intersection
			list<int> depositLocationKmeans;
			
			list<int> tmpDist;
			
			loop centroid from:0 to:length(coordinatesCentroids)-1 {
				tmpDist <- [];
				loop vertices from:0 to:length(roadNetwork.vertices)-1{
					add (point(roadNetwork.vertices[vertices]) distance_to coordinatesCentroids[centroid]) to: tmpDist;					
				}	
				loop vertices from:0 to: length(tmpDist)-1{
					if(min(tmpDist)=tmpDist[vertices]){
						add vertices to: depositLocationKmeans;
						break;
					}
				}	
			}
			
			// Final Outcome K-means
			depositLocation <- depositLocationKmeans;
		
		// -------------------------------------------The Robots or the Truck -----------------------------------------
		if (truckOrRobots=true){
			loop i from: 0 to: length(depositLocation) - 1 {
				create deposit{
					location <- point(roadNetwork.vertices[depositLocation[i]]);
					trash <- 0;
					robots <- 0;
				}
			}
			create robot number:robotNum{						
				location <- point(one_of(roadNetwork.vertices)); 
				target <- location; 
				source <- location;
				carrying <- false;
				lowBattery <- false;
				speedDist <- 1;
				pheromoneToDiffuse <- 0.0;
				pheromoneMark <- 0.0;
				batteryLife <- rnd(maxBatteryLife);
				speedDist <- maxSpeedDist;
				
			    //UDP SERVER FOR EACH ROBOT
				do connect to: "localhost" protocol: "udp_server" port: 9820;
				
				//UDP CLIENT FOR EACH ROBOT
				do connect to: "localhost" protocol: "udp_emitter" port: 9820 with_name: "epuck";
								
			}		
		}else{
			create truck number:robotNum{	
				location <- one_of(road);  
				//target <- point(roadNetwork.vertices[1]); 
				source <- location;	
				speedDist <- 1;  
				timeToStart <- 0;
				currentRoad <- 1;	
				}
		}
		// ----------------------------------The RFIDs tag on each road intersection------------------------
		loop i from: 0 to: length(roadNetwork.vertices) - 1 {
			create tagRFID{ 								
				id <- i;
				checked <- false;					
				location <- point(roadNetwork.vertices[i]); 
				pheromones <- [0.0,0.0,0.0,0.0,0.0];
				pheromonesToward <- neighbors_of(roadNetwork,roadNetwork.vertices[i]);  //to know what edge is related  to that amount of pheromone
				
				// Find the closest Deposit and set torwardDeposit and distanceToDeposit
				ask deposit closest_to self {
					myself.distanceToDeposit <- int(point(roadNetwork.vertices[i]) distance_to self.location);
					loop y from: 0 to: length(depositLocation) - 1 {
						if (point(roadNetwork.vertices[depositLocation[y]]) = self.location){
							myself.towardDeposit <- point(roadNetwork.vertices[allPairs[depositLocation[y],i]]);
							if (myself.towardDeposit=point(roadNetwork.vertices[i])){
								myself.towardDeposit <- point(roadNetwork.vertices[depositLocation[y]]);
							}
							break;
						}				
					}					
				}				
				type <- 'roadIntersection';				
				loop y from: 0 to: length(depositLocation) - 1 {
					if (i=depositLocation[y]){
						type <- 'Deposit&roadIntersection';
					}
				}	
								
			}
		}
	}
	
	action initPop{
		  ask people {do die;}
		  int nbPeopleToCreatePerBuilding;
		  ask building where  (each.usage="R"){ 
		    nbPeopleToCreatePerBuilding <- int((self.scale="S") ? (area/density_map[2])*nbFloors: ((self.scale="M") ? (area/density_map[1])*nbFloors:(area/density_map[0])*nbFloors));
		    //do createPop(10,self,false);	
		    do createPop(nbPeopleToCreatePerBuilding/pop_scale,self,false);			
		  }
		  if(length(density_array)>0){
			  ask amenity where  (each.usage="R"){	
				  	float nb <- (self.scale ="L") ? density_array[0] : ((self.scale ="M") ? density_array[1] :density_array[2]);
				  	do createPop(1+nb/3,self,true);
			  }
			  write "initPop from density array" + density_array + " nb people: " + length(people); 
		  }
		  else{
		  	write "density array is empty";
		  }
		  
		  do assignPopularity();
		}
	
	action stop_experiment {
		ask experiment {
			do die;
		}
	}
	
	action initGrid{
  		ask amenity where (each.fromGrid=true){
  			do die;
  		}
		if(onlineGrid = true){
		  cityMatrixData <- json_file(cityIOUrl).contents;
		  if (length(list(cityMatrixData["grid"])) = nil){
		  	cityMatrixData <- json_file("https://cityio.media.mit.edu/api/table/citymatrix_volpe").contents;
		  }
	    }
	    else{
	      cityMatrixData <- json_file("../includes/cityIO_Kendall.json").contents;
	    }	
		cityMatrixCell <- cityMatrixData["grid"];
		density_array <- list<float>(map(cityMatrixData["objects"])["density"]);
		toggle1 <- int(map(cityMatrixData["objects"])["toggle1"]);	
		loop l over: cityMatrixCell { 
		      create amenity {
		      	  id <-int(l["type"]);
		      	  x<-l["x"];
		      	  y<-l["y"];
				  location <- {	center.x + (13-l["x"])*brickSize,	center.y+ l["y"]*brickSize};  
				  location<- {(location.x * cos(angle) + location.y * sin(angle)),-location.x * sin(angle) + location.y * cos(angle)};
				  shape <- square(brickSize*0.9) at_location location;	
				  size<-10+rnd(10);
				  fromGrid<-true;  
				  scale <- citymatrix_map_settings[id][1];
				  usage<-citymatrix_map_settings[id][0];
				  color<-color_map[scale];
				  if(id!=-1 and id!=-2 and id!=7){
				  	density<-density_array[id];
				  }
              }	        
        }
        ask amenity{
          if ((x = 0 and y = 0) and fromGrid = true){
            do die;
          }
        }
		cityMatrixData <- json_file(cityIOUrl).contents;
		density_array <- map(cityMatrixData["objects"])["density"];
		
		if(cycle>10 and dynamicPop =true){
		if(current_density_array[0] < density_array[0]){
			float tmp<-length(people where each.fromTheGrid) * (density_array[0]/current_density_array[0] -1);
			do generateSquarePop(tmp,"L");			
		}
		if(current_density_array[0] > density_array[0]){
			float tmp<-length(people where (each.fromTheGrid))*(1-density_array[0]/current_density_array[0]);
			ask tmp  among (people where (each.fromTheGrid and each.scale="L")){
				do die;
			}
		}
		if(current_density_array[1] < density_array[1]){
			float tmp<-length(people where each.fromTheGrid) * (density_array[1]/current_density_array[1] -1);
			do generateSquarePop(tmp,"M");	
		}
		if(current_density_array[1] > density_array[1]){
			float tmp<-length(people where (each.fromTheGrid))*(1-density_array[1]/current_density_array[1]);
			ask tmp  among (people where (each.fromTheGrid and each.scale="M")){
				do die;
			}
		}
		if(current_density_array[2] < density_array[2]){
			float tmp<-length(people where each.fromTheGrid) * (density_array[2]/current_density_array[2] -1);
			do generateSquarePop(tmp,"S");
		}
		if(current_density_array[2] > density_array[2]){
			float tmp<-length(people where (each.fromTheGrid))*(1-density_array[2]/current_density_array[2]);
			ask tmp  among (people where (each.fromTheGrid and each.scale="S")){
				do die;
			}
		}
		}
        current_density_array<-density_array;		
	}
	

		
	reflex updateGrid when: ((cycle mod refresh) = 0) and (dynamicGrid = true) and (cityMatrix=true){		
		do initGrid;
	}
	
	reflex updateGraph when:(drawInteraction = true){// or toggle1 = 7){
		interaction_graph <- graph<people, people>(people as_distance_graph(distance));
	}
		
	reflex initSim when: ((cycle mod 8640) = 0){
		do initPop;
		current_day<-current_day mod 6 +1;
		if (current_day = stop_sim_day + 1 and stop_simulation = true) {
			is_sim_stopped <- true;
			write "Stopped";
			do stop_experiment;
		}		
	}
	
		
	action generateSquarePop(int nb, string _scale){
		create people number:nb	{
				living_place <- one_of(amenity where (each.scale=_scale and each.fromGrid));
				location <- any_location_in (living_place);
				scale <- _scale;	
				speed <- min_speed + rnd (max_speed - min_speed) ;
				initialSpeed <-speed;
				time_to_work <- min_work_start + rnd (max_work_start - min_work_start) ;
				time_to_lunch <- min_lunch_start + rnd (max_lunch_start - min_lunch_start) ;
				time_to_rework <- min_rework_start + rnd (max_rework_start - min_rework_start) ;
				time_to_dinner <- min_dinner_start + rnd (max_dinner_start - min_dinner_start) ;
				time_to_sleep <- min_work_end + rnd (max_work_end - min_work_end) ;
				working_place <- one_of(building  where (each.usage="O" and each.scale=scale)) ;
				eating_place <- one_of(amenity where (each.scale=scale )) ;
				dining_place <- one_of(amenity where (each.scale=scale )) ;
				objective <- "resting";
				fromTheGrid<-true; 
			}
	}
}

species building schedules: [] {
	string usage;
	string scale;
	float nbFloors<-1.0;//1 by default if no value is set.
	int depth;	
	float area;
	float perimeter;
	
	action createPop (int nb, building bd,bool fromGrid){
	  create people number: nb { 
  		living_place <- bd;
		location <- any_location_in (living_place);
		scale <- bd.scale;	
		speed <- min_speed + rnd (max_speed - min_speed);
		initialSpeed <-speed;
		time_to_work <- min_work_start + rnd (max_work_start - min_work_start) ;
		time_to_lunch <- min_lunch_start + rnd (max_lunch_start - min_lunch_start) ;
		time_to_rework <- min_rework_start + rnd (max_rework_start - min_rework_start) ;
		time_to_dinner <- min_dinner_start + rnd (max_dinner_start - min_dinner_start) ;
		time_to_sleep <- min_work_end + rnd (max_work_end - min_work_end) ;
		working_place <- one_of(building  where (each.usage="O" and each.scale=scale)) ;
		eating_place <- one_of(amenity where (each.scale=scale )) ;
		dining_place <- one_of(amenity where (each.scale=scale )) ;
		objective <- "resting";
		fromTheGrid<-fromGrid;  
	  }
	}
	
	aspect base {	
     	draw shape color: rgb(255,255,255);
	}
	aspect borderflat {	
     	draw shape color: rgb(255,255,255) empty:true border:rgb(30,30,50);
	}
	aspect realistic {	
     	draw shape color: rgb(255,255,255) depth:depth*0.25;
	}
	aspect usage{
		draw shape color: color_map[usage];
	}
	aspect scale{
		draw shape color: color_map[scale];
	}
	
	aspect demoScreen{
		if(toggle1=1){
			draw shape color: color_map[usage];
		}
		if(toggle1=2){
			if(usage="O"){
			  draw shape color: color_map[scale];
			}
		}
		if(toggle1=3){
			if(usage="R"){
			  draw shape color: color_map[scale];
			}
		}
	}
}

species road  schedules: []{
	rgb color <- #red ;
	aspect base {
		draw shape color:rgb(50,50,80);
	}
}

species table{ 
	aspect base {
		draw shape empty:true border:rgb(75,75,75) color: rgb(75,75,75) ;
	}	
}

species barrel parent:Litter{

	float total_trash <- 0.0;
	
	aspect base {
		draw shape empty:false border:rgb(75,75,75) color: rgb(75,75,75) ;
		draw circle(max_distance) color: circle_color;
	}
	
	action kill{
		do die;
	}
	
	action set_color(rgb new_color){
		circle_color <- new_color;
		
	}
}

experiment selfOrganizedGarbageCollection type: gui {
	parameter "NumberOfDeposits" var: depositNum min: 1 max: 5 step: 1 init:1;
	parameter "AdditionalTrashBin" var: additionalTrashBin min: 0 max: 100 step: 2;
	parameter "PheromoneMarkIntensity" var: singlePheromoneMark min: 0.01 max: 0.01 step: 0.1;
	parameter "EvaporatioRate" var: evaporation min: 0.001 max: 1.0 step: 0.001;
	parameter "DiffusionRate" var: diffusion min: 0.001 max: 1.0 step: 0.001;
	parameter "exploratoryRate" var: exploratoryRate min: 0.0 max: 0.05 step: 1.0;
	parameter "maxTrashPerBin" var: maxTrash min: 1.0 max: 50.0 step: 1.0;
	parameter "carriableTrashAmount" var: carriableTrashAmount min: 1 max: 50 step: 5;
		
	output {
		display city_display type:opengl draw_env:false autosave:false background:#black 
		{			
			species road aspect:base refresh:false;
			species building aspect: borderflat refresh:false;
			species pheromoneRoad aspect: pheromoneLevel ;
			species people aspect:scale transparency:0.5;
			species tagRFID aspect: realistic ;
			species trashBin aspect: realistic ;
			species robot aspect: realistic trace:traceLength fading:true;
			species deposit aspect: realistic transparency:0.8;	
			//species truck aspect: base ;
			
	   		overlay position: { world.shape.width*0.85, world.shape.height*0.85 } size: { 240 #px, 680 #px } background: # white transparency: 1.0 border: #black 
        	{
		  		map<string,rgb> list_of_existing_species <- map<string,rgb>(["RFID"::#green,"Deposit"::#blue,"Robot"::#cyan,"TrashBin"::#orange]);
            	loop i from: 0 to: length(list_of_existing_species) -1 {
             	//draw list_of_existing_species.keys[i] at: { 40#px, (i+1)*20#px } color: #black font: font("Helvetica", 18, #bold) perspective:false;
              	//draw circle(10#px) at: { 20#px, (i+1)*20#px } color: list_of_existing_species.values[i]  border: #white; 			
		  	} 				
		}
    	}	
	}
}


experiment selfOrganizedGarbageCollection_projector type: gui {
	parameter "NumberOfDeposits" var: depositNum min: 1 max: 5 step: 1 init:1;
	parameter "AdditionalTrashBin" var: additionalTrashBin min: 0 max: 100 step: 2;
	parameter "PheromoneMarkIntensity" var: singlePheromoneMark min: 0.01 max: 0.01 step: 0.1;
	parameter "EvaporatioRate" var: evaporation min: 0.001 max: 1.0 step: 0.001;
	parameter "DiffusionRate" var: diffusion min: 0.001 max: 1.0 step: 0.001;
	parameter "exploratoryRate" var: exploratoryRate min: 0.0 max: 0.05 step: 1.0;
	parameter "maxTrashPerBin" var: maxTrash min: 1.0 max: 50.0 step: 1.0;
	parameter "carriableTrashAmount" var: carriableTrashAmount min: 1 max: 50 step: 5;
		
	output {
		display city_display type:opengl draw_env:false autosave:false background:#black 
		camera_location: {1100.1511,917.4679,3164.084} camera_target: {1100.1511,917.4126,8.0E-4} camera_orientation: {0.0,1.0,0.0}
		toolbar: false fullscreen:1 
		keystone: [{-0.22588818525582727,-0.2094179817203352,0.0},{-0.41671690155040386,1.2543715798906692,0.0},{1.1947275240889739,1.234635853864672,0.0},{1.089574661080928,-0.1403429406293346,0.0}] 
		{	
			species road aspect:base refresh:false;
			species building aspect: usage;
			species pheromoneRoad aspect: pheromoneLevel ;
			species people aspect: scale transparency:0;
			species tagRFID aspect: realistic ;
			species trashBin aspect: realistic ;
			species deposit aspect: realistic transparency:0.25;	
			species robot aspect: projector;			
	   		overlay position: { world.shape.width*0.85, world.shape.height*0.85 } size: { 480 #px, 680 #px } background: # white transparency: 1.0 border: #black 
        	{
		  		map<string,rgb> list_of_existing_species <- map<string,rgb>(["RFID"::#green,"Deposit"::#blue,"Robot"::#cyan,"TrashBin"::#orange]);
            	loop i from: 0 to: length(list_of_existing_species) -1 {
             	//draw list_of_existing_species.keys[i] at: { 40#px, (i+1)*20#px } color: #black font: font("Helvetica", 18, #bold) perspective:false;
              	//draw circle(10#px) at: { 20#px, (i+1)*20#px } color: list_of_existing_species.values[i]  border: #white; 			
		  	} 				
		}
    	}	
	}
}


