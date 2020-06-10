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
	graph the_road;
	
	
	
	
	file roads_shapefile <- file("../includes/Intersection.shp");
	//geometry shape <- square(500);
	geometry shape <- envelope(roads_shapefile)+1;
	point center <- shape.centroid;
	
	
	init{
		//Creating the graph based on the QGIS version (ANOTHER SOLUTION TO THE PROBLEM)
		/*** 
		list<point> nodes <- [];
		the_road <- spatial_graph([]);
		
		//Adding the vertices
		the_road <- the_road add_node({0,0});
		the_road <- the_road add_node({0,410});
		the_road <- the_road add_node({410,410});
		the_road <- the_road add_node({410,0});
		
		the_road <- the_road add_node({20,20});
		the_road <- the_road add_node({20,390});
		the_road <- the_road add_node({390,20});
		the_road <- the_road add_node({390,390});
		
		//Adding the edges
		the_road <- the_road add_edge({0,0}::{0,410});
		the_road <- the_road add_edge({0,0}::{410,0});
		the_road <- the_road add_edge({410,410}::{0,410});
		the_road <- the_road add_edge({410,410}::{410,0});
		
		the_road <- the_road add_edge({20,20}::{20,390});
		the_road <- the_road add_edge({20,20}::{390,20});
		the_road <- the_road add_edge({390,390}::{20,390});
		the_road <- the_road add_edge({390,390}::{390,20});
		***/
		
		
		
		
		
		create toio number: 1{
			location <- center;
			//do connect to: url protocol: "udp_emitter" port: port ;
		}
		create road from: roads_shapefile;
		the_road <- as_edge_graph(road);
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
		do wander on: the_road;
		//do goto target:{0,300} on:the_road;
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
		display view{
			
			
			//There is a bug with the image not shwoing the toio all the time. FIX!!!
			image "../includes/Roads.png";
			species toio aspect: body;
			species road aspect: base;
        }
	}
}
