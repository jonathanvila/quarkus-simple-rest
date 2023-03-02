package org.vilojona;

import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;

@Path("/")
public class GreetingResource {

    @GET
    @Produces(MediaType.TEXT_PLAIN)
    @Path("hello")
    public String hello() {
        return "Hello from RESTEasy Reactive";
    }    
    
    @GET
    @Produces(MediaType.TEXT_PLAIN)
    @Path("echo/{input}")
    public String echo(@PathParam("input") String input) {
        return "Echo from RESTEasy: " + input;
    }
}