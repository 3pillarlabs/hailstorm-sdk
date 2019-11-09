package com.tpg.labs.hailstormfs;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class CorsConfiguration implements WebMvcConfigurer {

    private Logger logger = LoggerFactory.getLogger(CorsConfiguration.class);

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        logger.info("Configuring Global CORS");
        registry.addMapping("/**")
                .allowedOrigins("*")
                .allowedMethods("GET", "HEAD", "PUT", "PATCH", "POST", "DELETE", "OPTIONS")
                .allowedHeaders("*");
    }
}
