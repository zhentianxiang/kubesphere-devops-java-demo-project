package com.example.halloworld;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.core.env.Environment;

@SpringBootApplication
public class HalloworldApplication {

	public static void main(String[] args) {
		ConfigurableApplicationContext ctx = SpringApplication.run(HalloworldApplication.class, args);
		Environment env = ctx.getEnvironment();
		String[] activeProfiles = env.getActiveProfiles();
		String active = activeProfiles.length > 0 ? String.join(",", activeProfiles) : "default";
		System.out.println("[ENV] Active profile(s): " + active);
	}

}
