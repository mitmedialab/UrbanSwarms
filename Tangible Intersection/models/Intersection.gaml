/***
* Name: TangibleIntersection
* Author: mugui
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model Intersection


/**
 * Basic environment representing a real size pad.
 */
global{
	//For UDP communication with Processing App
	int port <- 6000;
	string url <- "localhost";
	graph the_graph;
	
	
	file roads_shapefile <- file("../includes/Intersection.shp");
	geometry shape <- envelope(roads_shapefile);
	point center <- shape.centroid;
	
	
	init{
		create toio number: 1{
			location <- center;
			//do connect to: url protocol: "udp_emitter" port: port ;
		}
		create road from: roads_shapefile;
		the_graph <- as_edge_graph(road);
	}
	
}


species road  {
	rgb color <- #red ;
	aspect base {
		draw shape color: color ;
	}
}

/**
 * Toio robot that moves in the pad. Real sized
 */
species toio skills:[moving, network]{
	
	//Food it wants to eat
	
	point target;
	init{
		speed <- 2.0;
	}
	
	//Communication test
	//reflex fetch when:has_more_message(){	
	//	loop while:has_more_message()
	//	{
	//		message s <- fetch_message();
	//		list coordinates <- string(s.contents) split_with(";");
	//		//location <- {int(coordinates[0]),int(coordinates[1])};
	//	}
	//}
	

	reflex move{
		do wander on: the_graph;
	}

	
	
	//Regular square with triangle representing the direction at which it is facing
	aspect body{
		draw square(11) color: #blue rotate: heading;
		draw triangle(1) rotate:90 + heading color: #red;
	}
}


experiment simple_movement type:gui{
	float minimum_cycle_duration <- 0.05;
	output{
		display view type:opengl{
			
			//There is a bug with the image not shwoing the toio all the time. FIX!!!
			image "../includes/Roads.png";
			species toio aspect: body;
			species road aspect: base;
		}
	}
}
