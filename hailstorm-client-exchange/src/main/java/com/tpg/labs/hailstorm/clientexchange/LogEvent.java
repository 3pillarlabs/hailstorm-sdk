package com.tpg.labs.hailstorm.clientexchange;

import com.fasterxml.jackson.annotation.JsonIgnore;

import java.time.Clock;

public class LogEvent {

    @JsonIgnore
    private static final String[] LEVEL_LABELS = new String[] {
            "DEBUG",
            "INFO",
            "WARN",
            "ERROR",
            "FATAL"
    };

    private String projectCode;
    private long timestamp;
    private int priority;
    private String level;
    private String message;

    public LogEvent() {

    }

    public LogEvent(String projectCode, long timestamp, int priority, String level, String message) {
        this.projectCode = projectCode;
        this.timestamp = timestamp;
        this.priority = priority;
        this.level = level;
        this.message = message;
    }

    public LogEvent(String projectCode, int priority, String message) {
        this(projectCode,
                Clock.systemUTC().millis(),
                priority,
                LEVEL_LABELS[priority],
                message);
    }

    public String getProjectCode() {
        return projectCode;
    }

    public void setProjectCode(String projectCode) {
        this.projectCode = projectCode;
    }

    public long getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(long timestamp) {
        this.timestamp = timestamp;
    }

    public int getPriority() {
        return priority;
    }

    public void setPriority(int priority) {
        this.priority = priority;
    }

    public String getLevel() {
        return level;
    }

    public void setLevel(String level) {
        this.level = level;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    @JsonIgnore
    public LogEvent decorate(double jitter) {
        this.timestamp = System.currentTimeMillis() + new Double(jitter * 1000000).longValue();
        this.level = LEVEL_LABELS[this.priority];
        return this;
    }
}
