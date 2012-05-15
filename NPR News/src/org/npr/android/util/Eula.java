/*
 * Copyright (C) 2008 The Android Open Source Project
 * 
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not
 * use this file except in compliance with the License. You may obtain a copy of
 * the License at
 * 
 * http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations under
 * the License.
 */

package org.npr.android.util;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.SharedPreferences;

import org.npr.android.news.R;

/**
 * Displays an EULA ("End User License Agreement") that the user has to accept
 * before using the application. Your application should call
 * {@link Eula#showEula(android.app.Activity)} in the onCreate() method of the
 * first activity. If the user accepts the EULA, it will never be shown again.
 * If the user refuses, {@link android.app.Activity#finish()} is invoked on your
 * activity.
 */
public class Eula {
  private static final String PREFERENCE_EULA_ACCEPTED = "eula.accepted";
  private static final String PREFERENCES_EULA = "eula";

  /**
   * Displays the EULA if necessary. This method should be called from the
   * onCreate() method of your main Activity.
   * 
   * @param activity The Activity to finish if the user rejects the EULA.
   */
  public static void showEula(final Activity activity) {
    final SharedPreferences preferences =
        activity.getSharedPreferences(PREFERENCES_EULA, Activity.MODE_PRIVATE);
    if (!preferences.getBoolean(PREFERENCE_EULA_ACCEPTED, false)) {
      final AlertDialog.Builder builder = new AlertDialog.Builder(activity);
      builder.setTitle(R.string.msg_eula_title);
      builder.setCancelable(true);
      builder.setPositiveButton(R.string.msg_eula_accept,
          new DialogInterface.OnClickListener() {
            public void onClick(DialogInterface dialog, int which) {
              accept(preferences);
            }
          });
      builder.setNegativeButton(R.string.msg_eula_refuse,
          new DialogInterface.OnClickListener() {
            public void onClick(DialogInterface dialog, int which) {
              refuse(activity);
            }
          });
      builder.setOnCancelListener(new DialogInterface.OnCancelListener() {
        public void onCancel(DialogInterface dialog) {
          refuse(activity);
        }
      });
      builder.setMessage(
          FileUtils.readFile(activity.getResources(), R.raw.eula)
      );
      builder.create().show();
    }
  }

  private static void accept(SharedPreferences preferences) {
    preferences.edit().putBoolean(PREFERENCE_EULA_ACCEPTED, true).commit();
  }

  private static void refuse(Activity activity) {
    activity.finish();
  }

}