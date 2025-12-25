package com.example.halloworld.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ResponseBody;
import java.net.InetAddress;
import java.lang.management.ManagementFactory;
import java.lang.management.MemoryMXBean;
import java.lang.management.OperatingSystemMXBean;

@Controller
public class HalloController {
	private static final Logger logger = LoggerFactory.getLogger(HalloController.class);

	@Autowired
	private Environment environment;




	@GetMapping("/sip")
	@ResponseBody
	public String getServerInfo() {
		try {
			InetAddress addr = InetAddress.getLocalHost();
			return String.format("{\"ip\":\"%s\",\"hostname\":\"%s\"}",
					addr.getHostAddress(),
					addr.getHostName());
		} catch (Exception e) {
			return "{\"error\":\"无法获取主机信息\"}";
		}
	}

	@GetMapping("/")
	public String index(Model model) {
		String active = environment.getProperty("spring.profiles.active", "dev");
		String display = environment.getProperty("app.env.display", active.toUpperCase());
		model.addAttribute("env", display);
		model.addAttribute("appName", environment.getProperty("spring.application.name", "halloworld-service"));
		model.addAttribute("title", "Halloworld - " + display);
		model.addAttribute("year", java.time.Year.now().getValue());
		return "index";
	}

	@GetMapping("/health")
	@ResponseBody
	public HealthInfo healthCheck() {
		MemoryMXBean memoryBean = ManagementFactory.getMemoryMXBean();
		OperatingSystemMXBean osBean = ManagementFactory.getOperatingSystemMXBean();

		return new HealthInfo(
				"running",
				Runtime.getRuntime().availableProcessors(),
				osBean.getSystemLoadAverage(),
				memoryBean.getHeapMemoryUsage().getUsed() / (1024 * 1024),
				memoryBean.getHeapMemoryUsage().getMax() / (1024 * 1024),
				System.currentTimeMillis()
		);
	}



	public static class HealthInfo {
		private String status;
		private int availableProcessors;
		private double systemLoad;
		private long usedMemoryMB;
		private long maxMemoryMB;
		private long timestamp;

		public HealthInfo(String status, int availableProcessors, double systemLoad,
						  long usedMemoryMB, long maxMemoryMB, long timestamp) {
			this.status = status;
			this.availableProcessors = availableProcessors;
			this.systemLoad = systemLoad;
			this.usedMemoryMB = usedMemoryMB;
			this.maxMemoryMB = maxMemoryMB;
			this.timestamp = timestamp;
		}

		// Getters
		public String getStatus() { return status; }
		public int getAvailableProcessors() { return availableProcessors; }
		public double getSystemLoad() { return systemLoad; }
		public long getUsedMemoryMB() { return usedMemoryMB; }
		public long getMaxMemoryMB() { return maxMemoryMB; }
		public long getTimestamp() { return timestamp; }
	}
}