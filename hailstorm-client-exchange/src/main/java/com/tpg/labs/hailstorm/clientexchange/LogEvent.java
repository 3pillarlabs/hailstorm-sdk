package com.tpg.labs.hailstorm.clientexchange;

import com.fasterxml.jackson.annotation.JsonIgnore;

public class LogEvent {

    private String projectCode;
    private long timestamp;
    private int priority;
    private String level;
    private String message;
    private long id;

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

    public long getId() {
        return id;
    }

    public void setId(long id) {
        this.id = id;
    }

    @JsonIgnore
    public static LogEvent build(LogEvent original) {
        original.setId(original.getTimestamp() * new Double(Math.ceil(Math.random() * 1000)).longValue());
        return original;
    }
}
