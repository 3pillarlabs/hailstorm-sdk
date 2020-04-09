package com.tpg.labs.hailstorm.clientexchange;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.stereotype.Controller;
import reactor.core.publisher.Flux;

@Controller
public class LogsController {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());
    private LogsService logsService;

    @Autowired
    public void setLogsService(LogsService logsService) {
        this.logsService = logsService;
    }

    @MessageMapping("logs")
    public Flux<LogEvent> logs() {
        return logsService.logStream();
    }
}
