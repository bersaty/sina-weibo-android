package com.monyetmabuk.rajawali.tutorials;

import android.os.Bundle;

public class RajawaliSphereMapActivity extends RajawaliExampleActivity {
	private RajawaliSphereMapRenderer mRenderer;
	
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		mRenderer = new RajawaliSphereMapRenderer(this);
		mRenderer.setSurfaceView(mSurfaceView);
		super.setRenderer(mRenderer);
		initLoader();
	}
}
