package rajawali.animation;

import java.util.ArrayList;
import java.util.List;
import java.util.Timer;
import java.util.TimerTask;

import rajawali.ATransformable3D;
import android.view.animation.Interpolator;
import android.view.animation.LinearInterpolator;

public class Animation3D {
	public static final int INFINITE = -1;
	public static final int RESTART = 1;
	public static final int REVERSE = 2;
	
	protected long mDuration;
	protected Interpolator mInterpolator;
	protected int mRepeatCount;
	protected int mRepeatMode = RESTART;
	protected int mNumRepeats;
	protected int mDirection = 1;
	protected long mStartOffset;
	protected long mStartTime;
	protected long mDelay;
	protected long mUpdateRate = 1000/60;
	protected boolean mHasStarted;
	protected boolean mHasEnded;
	protected List<Animation3DListener> mAnimationListeners = new ArrayList<Animation3DListener>();
	protected Timer mTimer;
	protected ATransformable3D mTransformable3D;
	protected Animation3D mInstance;
	
	public Animation3D()
	{
		mInstance = this;
	}
	
	class UpdateTimeTask extends TimerTask {
		long millis;
		float interpolatedTime;
		
		   public void run() {
		      millis = System.currentTimeMillis() - mStartTime;
		      if(mDirection == -1) millis = mDuration - millis;
		      interpolatedTime = mInterpolator.getInterpolation((float)millis / (float)mDuration);
		      setHasStarted(true);

		      applyTransformation(interpolatedTime > 1 ? 1 : interpolatedTime < 0 ? 0 : interpolatedTime);
		      if(mDirection == 1 && interpolatedTime >= 1 || mDirection == -1 && interpolatedTime <= 0)
		      {
		    	  if(mRepeatCount == mNumRepeats)
		    	  {
		    		  setHasEnded(true);
					  cancel();
					  for(Animation3DListener listener : mAnimationListeners) {
					 	  listener.onAnimationEnd(mInstance);
					  }
		    	  }
		    	  else
		    	  {
		    		  if(mRepeatMode == REVERSE)
		    			  mDirection *= -1;
		    		  mStartTime = System.currentTimeMillis();
		    		  mNumRepeats++;
					  for(Animation3DListener listener : mAnimationListeners) {
						  listener.onAnimationRepeat(mInstance);
					  }
		    	  }
		      }
		   }
		}
	
	public void cancel() {
		if(mTimer != null) {
			TimerManager.getInstance().killTimer(mTimer);
		}
	}
	
	public void reset() {
		mStartTime = System.currentTimeMillis();
		mNumRepeats = 0;
	}
	
	public void start() {
		if(mInterpolator == null)
			mInterpolator = new LinearInterpolator();
		reset();
		if(mTimer == null) mTimer = TimerManager.getInstance().createNewTimer();
		try {
			mTimer.scheduleAtFixedRate(new UpdateTimeTask(), mDelay, mUpdateRate);
		} catch(IllegalStateException e) {
			// timer was cancelled
			mTimer = TimerManager.getInstance().createNewTimer();
			// try once more
			try {
				mTimer.scheduleAtFixedRate(new UpdateTimeTask(), mDelay, mUpdateRate);
			} catch(IllegalStateException ie) {
				
			}
		}
		for(Animation3DListener listener : mAnimationListeners) {
			listener.onAnimationStart(this);
		}
	}
	
	protected void applyTransformation(float interpolatedTime) {
		
	}
	
	public ATransformable3D getTransformable3D() {
		return mTransformable3D;
	}

	public void setTransformable3D(ATransformable3D transformable3D) {
		mTransformable3D = transformable3D;
	}
	
	public void setAnimationListener(Animation3DListener animationListener) {
		mAnimationListeners.clear();
		mAnimationListeners.add(animationListener);
	}
	
	public void addAnimationListener(Animation3DListener animationListener) {
		mAnimationListeners.add(animationListener);
	}
	
	public void setDuration(long duration) {
		mDuration = duration;
	}
	
	public long getDuration() {
		return mDuration;
	}
	
	/**
	 * AccelerateDecelerateInterpolator, AccelerateInterpolator, AnticipateInterpolator, AnticipateOvershootInterpolator, BounceInterpolator, CycleInterpolator, DecelerateInterpolator, LinearInterpolator, OvershootInterpolator
	 * 
	 * @param interpolator
	 */
	public void setInterpolator(Interpolator interpolator) {
		mInterpolator = interpolator;
	}
	
	public Interpolator getInterpolator() {
		return mInterpolator;
	}
	
	public void setRepeatCount(int repeatCount) {
		mRepeatCount = repeatCount;
	}
	
	public int getRepeatCount() {
		return mRepeatCount;
	}
	
	public void setRepeatMode(int repeatMode) {
		mRepeatMode = repeatMode;
	}
	
	public int getRepeatMode() {
		return mRepeatMode;
	}

	public boolean isHasStarted() {
		return mHasStarted;
	}

	public void setHasStarted(boolean hasStarted) {
		this.mHasStarted = hasStarted;
	}

	public boolean isHasEnded() {
		return mHasEnded;
	}

	public void setHasEnded(boolean hasEnded) {
		this.mHasEnded = hasEnded;
	}

	public long getDelay() {
		return mDelay;
	}

	public void setDelay(long delay) {
		mDelay = delay;
	}

	public long getUpdateRate() {
		return mUpdateRate;
	}

	public void setUpdateRate(long updateRate) {
		this.mUpdateRate = updateRate;
	}
}
