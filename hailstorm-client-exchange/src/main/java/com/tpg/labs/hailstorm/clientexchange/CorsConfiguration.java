package com.tpg.labs.hailstorm.clientexchange;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.config.CorsRegistry;
import org.springframework.web.reactive.config.WebFluxConfigurer;

@Configuration
public class CorsConfiguration implements WebFluxConfigurer {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        logger.info("Configuring Global CORS");
        registry.addMapping("/**")
                .allowedOrigins("*")
                .allowedMethods("GET", "HEAD", "PUT", "PATCH", "POST", "DELETE", "OPTIONS")
                .allowedHeaders("*");
    }
}
