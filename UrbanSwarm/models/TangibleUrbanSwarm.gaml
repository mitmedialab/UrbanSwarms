/***
* Name: TangibleUrbanSwarm
* Author: Arnaud Grignard
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model TangibleUrbanSwarm

global {
	int port <- 9877;
	string url <- "localhost";
	string algorithm <- "A*" among: ["A*", "Dijkstra", "JPS", "BF"] parameter: true;
	int neighborhood_type <- 8 among:[4,8] parameter: true;	
	
	geometry shape<-rectangle(150,100);
	init {
		create goal{
			location <- one_of (cell).location;
		}    
		create virtualAgent number: 10{
			target <- one_of (goal);
			location <- one_of (cell).location;
		}
		create PhysicalAgent number: 1 {
		   do connect to: url protocol: "udp_server" port: port ;
		}
		
	} 
}

grid cell cell_width:50 cell_height:50 neighbors: neighborhood_type optimizer: algorithm{
	
	rgb color <-  #white;
} 


species PhysicalAgent skills:[network] {
	
	reflex fetch when:has_more_message() {	
		loop while:has_more_message()
		{
			message s <- fetch_message();
			list coordinates <- string(s.contents) split_with(";");
			location <- {int(coordinates[0]),int(coordinates[1])};
		}
	}
	
	aspect default {
		draw circle(5) color: #red border: #black;
		
	}
}
	   
species virtualAgent skills:[moving] {
	goal target;
	float speed <- float(3);

	reflex move when: location != target{
		//We restrain the movements of the agents only at the grid of cells that are not obstacle using the on facet of the goto operator and we return the path
		//followed by the agent
		//the recompute_path is used to precise that we do not need to recompute the shortest path at each movement (gain of computation time): the obtsacles on the grid never change.
		do goto (on:list(cell), target:target, speed:speed, recompute_path: false);

	}
	aspect default {
		draw circle(5) color:#green border: #black;
		if (current_path != nil) {
			draw current_path.shape color: #red;
		} 
	}
}

species goal {
	aspect default { 
		draw triangle(2) color: #red;	
	}
}

experiment urbanGrid type: gui {
	float minimum_cycle_duration<-0.05;
	output {
		display objects_display type:opengl{
			grid cell lines: #black;
			species virtualAgent aspect: default ;
			species PhysicalAgent aspect:default;
			species goal aspect: default ;
		}
	}
}
