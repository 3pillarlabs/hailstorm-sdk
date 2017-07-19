package com.brickred.tsg.hailstorm;

public class ChartModel {

	private final String filePath;
	private final int width;
	private final int height;

	public ChartModel(String filePath, int width, int height) {
		super();
		this.filePath = filePath;
		this.width = width;
		this.height = height;
	}

	public String getFilePath() {
		return filePath;
	}

	public int getWidth() {
		return width;
	}

	public int getHeight() {
		return height;
	}

}
