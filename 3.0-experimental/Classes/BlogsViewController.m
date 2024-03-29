#import "BlogsViewController.h"
#import "BlogsTableViewCell.h"
#import "QuickPhotoViewController.h"
#import "UINavigationController+FormSheet.h"
#import "QuickPhotoUploadProgressController.h"
#import "UIImageView+Gravatar.h"
#import "InAppSettings.h"

@interface BlogsViewController (Private)
- (void) cleanUnusedMediaFileFromTmpDir;
- (void)setupPhotoButton;
- (void)setupReader;
- (void) setUpRightNavigationButtons;
- (void)showSettingsView:(id)sender;
@end

@implementation BlogsViewController
@synthesize resultsController, currentBlog, tableView;

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidUnload {
    [quickPhotoButton release]; quickPhotoButton = nil;
    [readerButton release]; readerButton = nil;
    self.tableView = nil;
    [appDelegate setCurrentBlogReachability: nil];
}

- (void)viewDidLoad {
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];
	appDelegate = (WordPressAppDelegate *)[[UIApplication sharedApplication] delegate];
	
    self.title = NSLocalizedString(@"Blogs", @"RootViewController_Title");
    /*self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
																							target:self
																							action:@selector(showAddBlogView:)] autorelease];
    */
    
    [self setUpRightNavigationButtons];
    
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Blogs", @"") style:UIBarButtonItemStyleBordered target:nil action:nil];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
	self.tableView.allowsSelectionDuringEditing = YES;
    
    NSError *error = nil;
    if (![self.resultsController performFetch:&error]) {
//        NSLog(@"Error fetching request (Blogs) %@", [error localizedDescription]);
    } else {
//        NSLog(@"fetched blogs: %@", [resultsController fetchedObjects]);
		//Start a check on the media files that should be deleted from disk
		[self performSelectorInBackground:@selector(cleanUnusedMediaFileFromTmpDir) withObject:nil];
    }

    [self setupPhotoButton];
	
	// Check to see if we should prompt about rating in the App Store
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	
	// Check for a launch counter
	if([prefs objectForKey:@"launch_count"] == nil) {
		// If it doesn't exist, add it starting at 1
		[prefs setObject:[NSNumber numberWithInt:1] forKey:@"launch_count"];
	}
	else {
		// If we've launched the app 80 times...
		if(([[prefs objectForKey:@"launch_count"] isEqualToNumber:[NSNumber numberWithInt:80]]) && 
		   ([prefs objectForKey:@"has_displayed_rating_prompt"] == nil)) {
			
			// If this is the 30th launch, display the alert
			UIAlertView *ratingAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"App Store Rating", @"") 
																  message:NSLocalizedString(@"If you like WordPress for iOS, we'd appreciate it if you could leave us a rating in the App Store. Would you like to do that now?", @"") 
																 delegate:self 
														cancelButtonTitle:NSLocalizedString(@"No", @"") 
														otherButtonTitles:NSLocalizedString(@"Yes", @""), nil];
			[ratingAlert show];
			[ratingAlert release];
			
			// Don't bug them again
			[prefs setObject:@"1" forKey:@"has_displayed_rating_prompt"];
		}
		else if([[prefs objectForKey:@"launch_count"] intValue] < 80) {
			// Increment our launch count
			int launchCount = [[prefs objectForKey:@"launch_count"] intValue];
			launchCount++;
			[prefs setObject:[NSNumber numberWithInt:launchCount] forKey:@"launch_count"];
		}
		[prefs synchronize];
	}
}

- (void)viewDidDisappear:(BOOL)animated {
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];
    [self cancel:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];
		
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(blogsRefreshNotificationReceived:) name:@"BlogsRefreshNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showBlogWithoutAnimation) name:@"NewBlogAdded" object:nil];

    //quick photo upload notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaDidUploadSuccessfully:) name:ImageUploadSuccessful object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaUploadFailed:) name:ImageUploadFailed object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(postDidUploadSuccessfully:) name:@"PostUploaded" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(postUploadFailed:) name:@"PostUploadFailed" object:nil];
    
	//status bar notification
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didChangeStatusBarFrame:) name:DidChangeStatusBarFrame object:nil];
	
	[self checkEditButton];
	[self setupPhotoButton];
}

- (void)viewWillDisappear:(BOOL)animated {
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super viewWillDisappear:animated];
}


- (void) setUpRightNavigationButtons {
    UIToolbar *tools = [[UIToolbar alloc]
                        initWithFrame:CGRectMake(0.0f, 0.0f, 128.0f, 44.01f)]; // 44.01 shifts it up 1px for some reason
     
    NSMutableArray *buttons = [[NSMutableArray alloc] initWithCapacity:3];
    
    // Settings button.
    UIBarButtonItem *bi = [[UIBarButtonItem alloc] initWithTitle:@"Settings" style:UIBarButtonItemStylePlain  target:self action:@selector(showSettingsView:)];
    bi.style = UIBarButtonItemStyleBordered;
    [buttons addObject:bi];
    [bi release];
    
  
    // Create a spacer.
    bi = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    bi.width = 10.0f;
    [buttons addObject:bi];
    [bi release];
    
    // Add blogs button.
    bi = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(showAddBlogView:)];
    bi.style = UIBarButtonItemStyleBordered;
    [buttons addObject:bi];
    [bi release];
    
    // Add buttons to toolbar and toolbar to nav bar.
    [tools setItems:buttons animated:NO];
    [buttons release];
    UIBarButtonItem *twoButtons = [[UIBarButtonItem alloc] initWithCustomView:tools];
    [tools release];
    self.navigationItem.rightBarButtonItem = twoButtons;
    [twoButtons release];
}


- (void) checkEditButton{
	[self.tableView reloadData];
	[self.tableView endEditing:YES];
	self.tableView.editing = NO;
	
    [self cancel:self]; // Shows edit button
}

- (void)blogsRefreshNotificationReceived:(NSNotification *)notification {
	[resultsController performFetch:nil];
	[appDelegate sendPushNotificationBlogsListInBackground]; 
	[self checkEditButton];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if (DeviceIsPad())
		return YES;
    else {
        return (interfaceOrientation == UIInterfaceOrientationPortrait);
    }
}

#pragma mark -
#pragma mark UITableView Delegate Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[resultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = nil;
    sectionInfo = [[resultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 52.0;
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"BlogCell";
    BlogsTableViewCell *cell = (BlogsTableViewCell *)[aTableView dequeueReusableCellWithIdentifier:CellIdentifier];
    Blog *blog = [resultsController objectAtIndexPath:indexPath];
    
    CGRect frame = CGRectMake(8,8,35,35);
    UIImageView* asyncImage = [[[UIImageView alloc] initWithFrame:frame] autorelease];
    
    if (cell == nil) {
        cell = [[[BlogsTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
        [cell.imageView removeFromSuperview];
    }
    else {
        UIImageView* oldImage = (UIImageView*)[cell.contentView viewWithTag:999];
        [oldImage removeFromSuperview];
    }
    
	asyncImage.layer.cornerRadius = 4.0;
	asyncImage.layer.masksToBounds = YES;
	asyncImage.tag = 999;
    asyncImage.opaque = YES;
	[asyncImage setImageWithBlavatarUrl:blog.blavatarUrl isWPcom:blog.isWPcom];
	[cell.contentView addSubview:asyncImage];
	
#if defined __IPHONE_3_0
    cell.textLabel.text = [blog blogName];
    cell.detailTextLabel.text = [blog hostURL];
#elif defined __IPHONE_2_0
    cell.text = [blog blogName];
#endif

    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    return cell;
}

-(NSString *)tableView:(UITableView*)aTableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
	return NSLocalizedString(@"Remove", @"");
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([aTableView cellForRowAtIndexPath:indexPath].editing) {
        Blog *blog = [resultsController objectAtIndexPath:indexPath];
		
		EditSiteViewController *editSiteViewController;
		editSiteViewController = [[EditSiteViewController alloc] initWithNibName:@"EditSiteViewController" bundle:nil];
		
        editSiteViewController.blog = blog;
		if (DeviceIsPad()) {
			UINavigationController *aNavigationController = [[UINavigationController alloc] initWithRootViewController:editSiteViewController];
			aNavigationController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
			aNavigationController.modalPresentationStyle = UIModalPresentationFormSheet;
			aNavigationController.navigationBar.tintColor = self.navigationController.navigationBar.tintColor;
			appDelegate.navigationController = aNavigationController;
			[appDelegate.splitViewController presentModalViewController:aNavigationController animated:YES];
			[self cancel:self];
			[aNavigationController release];
		}
		else {
			[self.navigationController pushViewController:editSiteViewController animated:YES];
		}
		[editSiteViewController release];
        [aTableView setEditing:NO animated:YES];
    }
	else {	// if ([self canChangeCurrentBlog]) {
        Blog *blog = [resultsController objectAtIndexPath:indexPath];
		[self showBlog:blog animated:YES];

		//we should keep a reference to the last selected blog
		if (DeviceIsPad() == YES) {
			self.currentBlog = blog;
		}
    }
	[aTableView deselectRowAtIndexPath:[aTableView indexPathForSelectedRow] animated:YES];
}

- (void)tableView:(UITableView *)aTableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
		
		Blog *blog = [resultsController objectAtIndexPath:indexPath];
		if([self canChangeBlog:blog]){
			[aTableView beginUpdates];
			
            [FileLogger log:@"Deleted blog %@", blog];
			[appDelegate.managedObjectContext deleteObject:blog];
			
			[aTableView endUpdates];
			NSError *error = nil;
			if (![appDelegate.managedObjectContext save:&error]) {
				WPFLog(@"Unresolved Core Data Save error %@, %@", error, [error userInfo]);
				exit(-1);
			}
			[appDelegate sendPushNotificationBlogsListInBackground];
		} else {
			//the blog is using the network connection and cannot be stoped, show a message to the user
			UIAlertView *blogIsCurrentlyBusy = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Info", @"Info alert title")
																		  message:NSLocalizedString(@"The blog is syncing with the server. Please try later.", @"")
																		 delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil];
			[blogIsCurrentlyBusy show];
			[blogIsCurrentlyBusy release];
		}
		blog = nil;
	}
}


- (void)edit:(id)sender {
	UIBarButtonItem *cancelButton = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", @"")
																	  style:UIBarButtonItemStyleDone
																	 target:self
																	 action:@selector(cancel:)] autorelease];
	[self.navigationItem setLeftBarButtonItem:cancelButton animated:YES];
	[self.tableView setEditing:YES animated:YES];
}

- (void)cancel:(id)sender {
    UIBarButtonItem *editButton = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Edit", @"")
																	style:UIBarButtonItemStylePlain
																   target:self
																   action:@selector(edit:)] autorelease];
    [self.navigationItem setLeftBarButtonItem:editButton animated:YES];
    [self.tableView setEditing:NO animated:YES];
}

#pragma mark -
#pragma mark Custom methods

- (void)setupPhotoButton {
    BOOL wantsPhotoButton = NO;
    BOOL wantsReaderButton = NO;
    
    if (!DeviceIsPad()
        && [[resultsController fetchedObjects] count] > 0) {
        if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]
            || [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
            wantsPhotoButton = YES;
        }
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"wpcom_username_preference"]) {
            wantsReaderButton = YES;
        }
    }
    if (quickPhotoButton.superview != nil) {
        [quickPhotoButton removeFromSuperview];
        [quickPhotoButton release]; quickPhotoButton = nil;
    }
    if (readerButton.superview != nil) {
        [readerButton removeFromSuperview];
        [readerButton release]; readerButton = nil;
    }
    if (!wantsReaderButton && !wantsPhotoButton) {
        self.tableView.contentInset = UIEdgeInsetsZero;
    } else {
        self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 83, 0);
    }
    if (wantsPhotoButton && quickPhotoButton == nil) {
        quickPhotoButton = [QuickPhotoButton button];
        [quickPhotoButton setImage:[UIImage imageNamed:@"camera.png"] forState:UIControlStateNormal];
        CGFloat x = wantsReaderButton ? (self.view.bounds.size.width / 2) : 0;
        CGFloat width = wantsReaderButton ? (self.view.bounds.size.width / 2) : self.view.bounds.size.width;
        quickPhotoButton.frame = CGRectMake(x, self.view.bounds.size.height - 83, width, 83);
        [quickPhotoButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [quickPhotoButton setTitle:NSLocalizedString(@"Photo", @"") forState:UIControlStateNormal];     
        [quickPhotoButton.titleLabel setFont:[UIFont boldSystemFontOfSize:17]];
        [quickPhotoButton setTitleShadowColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
        [quickPhotoButton addTarget:self action:@selector(quickPhotoPost) forControlEvents:UIControlEventTouchUpInside];
        [quickPhotoButton retain];
        [self.view addSubview:quickPhotoButton];
    }
    if (wantsReaderButton && readerButton == nil) {
        readerButton = [QuickPhotoButton button];
		[readerButton setImage:[UIImage imageNamed:@"read.png"] forState:UIControlStateNormal];
        CGFloat width = wantsPhotoButton ? self.view.bounds.size.width / 2 : self.view.bounds.size.width;
        readerButton.frame = CGRectMake(0, self.view.bounds.size.height - 83, width, 83);
        [readerButton setTitle:NSLocalizedString(@"Read", @"") forState:UIControlStateNormal];
        [readerButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [readerButton.titleLabel setFont:[UIFont boldSystemFontOfSize:17]];
        [readerButton setTitleShadowColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
        [readerButton addTarget:self action:@selector(showReader) forControlEvents:UIControlEventTouchUpInside];
        [readerButton retain];
        [self.view addSubview:readerButton];
    }
    if (!wantsReaderButton && readerViewController != nil) { 
        [readerViewController release]; 
        readerViewController = nil; 
    }
}

- (void)didChangeStatusBarFrame:(NSNotification *)notification {
	[self performSelectorOnMainThread:@selector(setupPhotoButton) withObject:nil waitUntilDone:NO];
}

- (void)setupReader { 
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)]; 
    if (readerViewController == nil) { 
        NSError *error = nil; 
        NSString *wpcom_username = [[NSUserDefaults standardUserDefaults] objectForKey:@"wpcom_username_preference"]; 
        NSString *wpcom_password = [SFHFKeychainUtils getPasswordForUsername:wpcom_username 
                                                              andServiceName:@"WordPress.com" 
                                                                       error:&error]; 
        if (wpcom_username && wpcom_password) { 
            readerViewController = [[WPReaderViewController alloc] initWithNibName:@"WPReaderViewController" bundle:nil]; 
            readerViewController.username = wpcom_username; 
            readerViewController.password = wpcom_password; 
            readerViewController.url = [NSURL URLWithString:kMobileReaderURL]; 
            [readerViewController view]; // Force web view preload 
        } 
    } 
} 


- (void)showReader { 
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)]; 
    if ( appDelegate.wpcomAvailable == NO ) {
        UIAlertView *connectionFailAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Sorry, no connection to WordPress.com.", @"")
																	  message:NSLocalizedString(@"The Reader is not available at this moment.", @"")
																	 delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil];
        [connectionFailAlert show];
        [connectionFailAlert release];
        return;
    }
    [self setupReader]; 
    [self.navigationController pushViewController:readerViewController animated:YES]; 
} 

- (void)showQuickPhoto:(UIImagePickerControllerSourceType)sourceType {
    QuickPhotoViewController *quickPhotoViewController = [[QuickPhotoViewController alloc] init];
    quickPhotoViewController.blogsViewController = self;
    quickPhotoViewController.sourceType = sourceType;
    [self.navigationController pushViewController:quickPhotoViewController animated:YES];
    [quickPhotoViewController release];
}

- (void)quickPhotoPost {
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];

	UIActionSheet *actionSheet;
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
		actionSheet = [[UIActionSheet alloc] initWithTitle:@"" 
												  delegate:self 
										 cancelButtonTitle:NSLocalizedString(@"Cancel", @"") 
									destructiveButtonTitle:nil 
										 otherButtonTitles:NSLocalizedString(@"Add Photo from Library", @""),NSLocalizedString(@"Take Photo", @""),nil];
	}
	else {
        [self showQuickPhoto:UIImagePickerControllerSourceTypePhotoLibrary];
        return;
	}
	
    actionSheet.actionSheetStyle = UIActionSheetStyleDefault;
	[actionSheet showInView:self.view];
    [appDelegate setAlertRunning:YES];
	
    [actionSheet release];
}

- (void) cleanUnusedMediaFileFromTmpDir {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSMutableArray *mediaToKeep = [NSMutableArray array];	
	//get a references to media files linked in a post
	for (Blog *blog in [resultsController fetchedObjects]) {
		NSSet *posts = blog.posts;
		if (posts && (posts.count > 0)) { 
			for (AbstractPost *post in posts) {
				//check for media file
				NSSet *mediaFiles = post.media;
				for (Media *media in mediaFiles) {
					[mediaToKeep addObject:media];
				}
				mediaFiles = nil;
			}
		}
		posts = nil;
	}
	
	//searches for jpg files within the app temp file
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	NSArray *contentsOfDir = [fileManager contentsOfDirectoryAtPath:documentsDirectory error:NULL];
	
	for (NSString *currentPath in contentsOfDir)
		if([currentPath isMatchedByRegex:@".jpg$"]) {
			NSString *filepath = [documentsDirectory stringByAppendingPathComponent:currentPath];
			
			BOOL keep = NO;
			//if the file is not referenced in any post we can delete it
			for (Media *currentMediaToKeepPath in mediaToKeep) {
				if([[currentMediaToKeepPath localURL] isEqualToString:filepath]) {
					keep = YES;
					break;
				}
			}
			
			if(keep == NO) {
				[fileManager removeItemAtPath:filepath error:NULL];
			}
		}
	
	[pool release];
}

- (BOOL)canChangeBlog:(Blog *) blog {
	//we should check  isSyncingPosts, isSyncingPages, isSyncingComments first bc is a fast check
	//we should first check if there are networks activities within the blog
	//we should re-check  isSyncingPosts, isSyncingPages, isSyncingComments;
	if(blog.isSyncingPosts || blog.isSyncingPages || blog.isSyncingComments)
		return NO;
	
	BOOL canDelete = YES;
	
	NSSet *posts = blog.posts;
	if (posts && (posts.count > 0)) { 
		for (AbstractPost *post in posts) {
			if(!canDelete) break;
			
			//check the post status
			if (post.remoteStatus == AbstractPostRemoteStatusPushing)
				canDelete = NO;
			
			//check for media file
			NSSet *mediaFiles = post.media;
			for (Media *media in mediaFiles) {
				if(!canDelete) break;
				if(media.remoteStatus == MediaRemoteStatusPushing) 
					canDelete = NO;
			}
			mediaFiles = nil;
		}
	}
	posts = nil;
	
	if(blog.isSyncingPosts || blog.isSyncingPages || blog.isSyncingComments)
		canDelete = NO;
	
	return canDelete;
}

- (void)showSettingsView:(id)sender {
    InAppSettingsViewController *settings = [[InAppSettingsViewController alloc] init];
    [self.navigationController pushViewController:settings animated:YES];
    [settings release];
}

- (void)showAddBlogView:(id)sender {
	WelcomeViewController *welcomeView = [[WelcomeViewController alloc] initWithNibName:@"WelcomeViewController" bundle:nil];
	if(DeviceIsPad() == YES) {
		WelcomeViewController *welcomeViewController = [[WelcomeViewController alloc] initWithNibName:@"WelcomeViewController-iPad" bundle:nil];
		UINavigationController *aNavigationController = [[UINavigationController alloc] initWithRootViewController:welcomeViewController];
		aNavigationController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
		aNavigationController.modalPresentationStyle = UIModalPresentationFormSheet;
        aNavigationController.navigationBar.tintColor = self.navigationController.navigationBar.tintColor;
		appDelegate.navigationController = aNavigationController;
		[appDelegate.splitViewController presentModalViewController:aNavigationController animated:YES];
		[aNavigationController release];
		[welcomeViewController release];
	}
	else {
		[self.navigationController pushViewController:welcomeView animated:YES];
	}
	[welcomeView release];
}

- (void)showBlogWithoutAnimation {
//    [self showBlog:NO];
}

- (void)showBlog:(Blog *)blog animated:(BOOL)animated {
	BlogViewController *blogViewController = [[BlogViewController alloc] initWithNibName:@"BlogViewController" bundle:nil];
    blogViewController.blog = blog;
    [appDelegate setCurrentBlog:blog];
    
   [appDelegate setCurrentBlogReachability: [Reachability reachabilityWithHostname:blog.hostURL] ];
    
    if (DeviceIsPad() == NO) {
        [self.navigationController pushViewController:blogViewController animated:animated];
    } else {        
        WordPressAppDelegate *delegate = (WordPressAppDelegate *)[[UIApplication sharedApplication] delegate];

        [blogViewController.view setFrame:CGRectMake(0, 0, panel_slide_width, self.view.frame.size.height)];
        [delegate.stackController pushViewController:blogViewController fromViewController:self animated:YES];
    }
    
	[blogViewController release];
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
	NSLog(@"Shake detected. Refreshing...");
	if(event.subtype == UIEventSubtypeMotionShake){
		
	}
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if(buttonIndex == 0) {
        [self showQuickPhoto:UIImagePickerControllerSourceTypePhotoLibrary];
    } else if(buttonIndex == 1) {
        [self showQuickPhoto:UIImagePickerControllerSourceTypeCamera];
    }
}

#pragma mark -
#pragma mark UIAlertView delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if(buttonIndex == 1) {
		// Take them to the App Store
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:NSLocalizedString(@"http://itunes.apple.com/us/app/wordpress/id335703880?mt=8", @"App URL, change 'us' for your local store code (test the link first)")]];
	}
}

#pragma mark -
#pragma mark Fetched results controller

- (NSFetchedResultsController *)resultsController {
    if (resultsController != nil) {
        return resultsController;
    }

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"Blog" inManagedObjectContext:appDelegate.managedObjectContext]];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"blogName" ascending:YES];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    [fetchRequest setSortDescriptors:sortDescriptors];

    // For some reasons, the cache sometimes gets corrupted
    // Since we don't really use sections we skip the cache here
    NSFetchedResultsController *aResultsController = [[NSFetchedResultsController alloc]
                         initWithFetchRequest:fetchRequest
                         managedObjectContext:appDelegate.managedObjectContext
                         sectionNameKeyPath:nil
                         cacheName:nil];
    self.resultsController = aResultsController;
    resultsController.delegate = self;

    [aResultsController release];
    [fetchRequest release];
    [sortDescriptor release]; sortDescriptor = nil;
    [sortDescriptors release]; sortDescriptors = nil;

    return resultsController;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
//    [self.tableView beginUpdates];
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
//    [self.tableView endUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
    if (self.navigationController.visibleViewController == self) {
        [self setupPhotoButton];
    }
    [self.tableView reloadData];
	
	if (!DeviceIsPad()) {
        return;
    }
	switch (type) {
        case NSFetchedResultsChangeDelete:
			//deleted the last selected blog
			if(currentBlog && (currentBlog == anObject)) {
				WordPressAppDelegate *delegate = (WordPressAppDelegate*)[[UIApplication sharedApplication] delegate];
				[delegate showContentDetailViewController:nil];
				currentBlog = nil;
			}
			break;
		default:
			break;
    }
}

- (void)uploadQuickPhoto:(Post *)post{
    
    appDelegate.isUploadingPost = YES;
    
    quickPicturePost = post;
    if (post != nil) {
        //remove the quick photo button w/ sexy animation
        CGRect frame = quickPhotoButton.frame;
        
        if (uploadController == nil) {
            uploadController = [[QuickPhotoUploadProgressController alloc] initWithNibName:@"QuickPhotoUploadProgressController" bundle:nil];
            uploadController.view.frame = CGRectMake(frame.origin.x, self.view.bounds.size.height + 83, frame.size.width, frame.size.height);
            [self.view addSubview:uploadController.view];
        }
        
        if (uploadController.spinner.alpha == 0.0) {
            //reset the uploading view
            [uploadController.spinner setAlpha: 1.0f];
            uploadController.label.frame = CGRectMake(uploadController.label.frame.origin.x, uploadController.label.frame.origin.y + 12, uploadController.label.frame.size.width, uploadController.label.frame.size.height);
        }
        [uploadController.spinner startAnimating];
        uploadController.label.textColor = [[UIColor alloc] initWithRed:70.0f/255.0f green:70.0f/255.0f blue:70.0f/255.0f alpha:1.0f];
        uploadController.label.text = NSLocalizedString(@"Uploading Quick Photo...", @"");
        
        //show the upload dialog animation
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:0.6f];
        quickPhotoButton.frame = CGRectMake(frame.origin.x, self.view.bounds.size.height + 83, frame.size.width, frame.size.height);
        frame = uploadController.view.frame;
        uploadController.view.frame = CGRectMake(frame.origin.x, self.view.bounds.size.height - 83, frame.size.width, frame.size.height);
        
        [UIView commitAnimations];
 
        //upload the image
        [[post.media anyObject] performSelector:@selector(upload) withObject:nil];
    }
}

- (void)showQuickPhotoButton: (BOOL)delay{
    CGRect frame = quickPhotoButton.frame;
    [UIView beginAnimations:nil context:nil]; 
    [UIView setAnimationDuration:0.6f];
    if (delay)
        [UIView setAnimationDelay:1.2f];
    
    quickPhotoButton.frame = CGRectMake(frame.origin.x, self.view.bounds.size.height - 83, frame.size.width, frame.size.height);
    
    frame = uploadController.view.frame;
    
    uploadController.view.frame = CGRectMake(frame.origin.x, self.view.bounds.size.height + 83, frame.size.width, frame.size.height);
    
    [UIView commitAnimations];
}

- (void)mediaDidUploadSuccessfully:(NSNotification *)notification {
    
    Media *media = (Media *)[notification object];
    [media save];
    quickPicturePost.content = [NSString stringWithFormat:@"%@\n\n%@", [media html], quickPicturePost.content];
    [quickPicturePost upload];    
}

- (void)mediaUploadFailed:(NSNotification *)notification {
    appDelegate.isUploadingPost = NO;
    [self showQuickPhotoButton: NO];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Quick Photo Failed", @"")
                                                    message:NSLocalizedString(@"Sorry, the photo upload failed. The post has been saved as a Local Draft.", @"")
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                          otherButtonTitles:nil];
    [alert show];
    [alert release];
}

- (void)postDidUploadSuccessfully:(NSNotification *)notification {
    appDelegate.isUploadingPost = NO;
    [UIView beginAnimations:nil context:nil]; 
    [UIView setAnimationDuration:0.6f];
    [uploadController.spinner setAlpha:0.0f];
    uploadController.label.text = NSLocalizedString(@"Published!", @"");
    uploadController.label.textColor = [[UIColor alloc] initWithRed:0.0f green:128.0f/255.0f blue:0.0f alpha:1.0f];
    uploadController.label.frame = CGRectMake(uploadController.label.frame.origin.x, uploadController.label.frame.origin.y - 12, uploadController.label.frame.size.width, uploadController.label.frame.size.height);
    [UIView commitAnimations];
    [self showQuickPhotoButton: YES];
}

- (void)postUploadFailed:(NSNotification *)notification {
    appDelegate.isUploadingPost = NO;
    [self showQuickPhotoButton: NO];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Quick Photo Failed", @"")
                                                    message:NSLocalizedString(@"Sorry, the photo publish failed. The post has been saved as a Local Draft.", @"")
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                          otherButtonTitles:nil];
    [alert show];
    [alert release];
}

#pragma mark -
#pragma mark Memory Management

- (void)didReceiveMemoryWarning {
    WPLog(@"%@ %@", self, NSStringFromSelector(_cmd));
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    self.resultsController = nil;
	self.currentBlog = nil;
    [appDelegate setCurrentBlogReachability: nil];
    [quickPhotoButton release]; quickPhotoButton = nil;
    self.tableView = nil;
    [quickPicturePost release];
    [uploadController release];
    [readerViewController release]; 
    [super dealloc];
}

@end
