package com.tpg.labs.hailstorm.clientexchange;

import reactor.core.publisher.Flux;

public interface LogsService {

    Flux<LogEvent> logStream();
}
