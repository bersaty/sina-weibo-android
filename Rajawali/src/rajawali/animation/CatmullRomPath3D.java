package rajawali.animation;

import java.util.Stack;

import rajawali.math.Number3D;
import android.util.FloatMath;

/**
 * Derived from http://www.cse.unsw.edu.au/~lambert/splines/source.html
 * 
 * @author dennis.ippel
 *
 */
public class CatmullRomPath3D implements ISpline {
	protected static final int EPSILON = 36;
	protected static final float DELTA = .00001f;
	protected Stack<Number3D> mPoints;
	protected int mNumPoints;
	protected int mSelectedIndex = -1;
	protected Number3D mCurrentTangent;
	protected Number3D mCurrentPoint;
	protected boolean mCalculateTangents;

	public CatmullRomPath3D() {
		mPoints = new Stack<Number3D>();
		mCurrentTangent = new Number3D();
		mCurrentPoint = new Number3D();
	}

	public void addPoint(Number3D point) {
		mPoints.add(point);
		mNumPoints++;
	}
	
	public int getNumPoints()
	{
		return mNumPoints;
	}
	
	public Number3D getPoint(int index) {
		return mPoints.get(index);
	}

	public Number3D calculatePoint(float t) {
		if(mCalculateTangents) {
			float prevt = t == 0 ? t + DELTA : t - DELTA;
			float nextt = t == 1 ? t - DELTA : t + DELTA;
			mCurrentTangent = p(prevt);
			Number3D nextp = p(nextt);
			mCurrentTangent.subtract(nextp);
			mCurrentTangent.multiply(.5f);
			mCurrentTangent.normalize();
		}
		
		return p(t);
	}

	protected Number3D p(float t) {
		int currentIndex = 2 + (int)FloatMath.floor((t == 1 ? t - .000001f : t) * (mNumPoints-3));
		float tdivnum = (t * (mNumPoints - 3)) - (currentIndex - 2);
		mCurrentPoint.setAll(0, 0, 0);
		
		for (int j = -2; j <= 1; j++) {
			float b = b(j, tdivnum);
			Number3D p = mPoints.get(currentIndex+j);
			
			mCurrentPoint.x += b * p.x;
			mCurrentPoint.y += b * p.y;
			mCurrentPoint.z += b * p.z;
		}
		return mCurrentPoint.clone();
	}

	protected float b(int i, float t) {
		switch (i) {
		case -2:
			return ((-t + 2) * t - 1) * t / 2;
		case -1:
			return (((3 * t - 5) * t) * t + 2) / 2;
		case 0:
			return ((-3 * t + 4) * t + 1) * t / 2;
		case 1:
			return ((t - 1) * t * t) / 2;
		}
		return 0;
	}
	
	public Number3D getCurrentTangent() {
		return mCurrentTangent;
	}

	public int selectPoint(Number3D point) {
		float minDist = Float.MAX_VALUE;
		mSelectedIndex = -1;
		for (int i = 0; i < mNumPoints; i++) {
			Number3D p = mPoints.get(i);
			float distance = sqrt(p.x - point.x) + sqrt(p.y - point.y) + sqrt(p.z - point.z);
			if (distance < minDist && distance < EPSILON) {
				minDist = distance;
				mSelectedIndex = i;
			}
		}
		return mSelectedIndex;
	}

	protected float sqrt(float value) {
		return value * value;
	}
	
	public void setCalculateTangents(boolean calculateTangents) {
		this.mCalculateTangents = calculateTangents;
	}
}
