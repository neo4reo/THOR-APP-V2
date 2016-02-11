//
//  DJIRootViewController.m
//

#import "DJIRootViewController.h"
#import "DJIGSButtonViewController.h"
#import "DJIWaypointConfigViewController.h"

#define kEnterNaviModeFailedAlertTag 1001

@interface DJIRootViewController ()<DJIGSButtonViewControllerDelegate, DJIWaypointConfigViewControllerDelegate>
@property (nonatomic, assign)BOOL isEditingPoints;
@property (nonatomic, strong)DJIGSButtonViewController *gsButtonVC;
@property (nonatomic, strong)DJIWaypointConfigViewController *waypointConfigVC;
@end

@implementation DJIRootViewController

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self startUpdateLocation];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    [self.locationManager stopUpdatingLocation];

    [self.phantomDrone.mainController stopUpdateMCSystemState];
    [self.phantomDrone disconnectToDrone];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self initUI];
    [self initData];
    [self initDrone];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden {
    return NO;
}

#pragma mark NSNotification Selector Method
- (void)registerAppSuccess:(NSNotification *)notification
{
    [self.phantomDrone connectToDrone];
    [self.phantomProMainController startUpdateMCSystemState];
}

#pragma mark Init Methods
-(void)initData
{
    self.userLocation = kCLLocationCoordinate2DInvalid;
    self.droneLocation = kCLLocationCoordinate2DInvalid;
    
    self.mapView.delegate = self;
    self.mapView.mapType = MKMapTypeSatelliteFlyover;
    self.mapView.showsBuildings = YES;
    self.mapCamera = [[MKMapCamera alloc]init];

    self.mapController = [[DJIMapController alloc] init];
    self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(addWaypoints:)];
    [self.mapView addGestureRecognizer:self.tapGesture];


}

-(void) initUI
{
    self.modeLabel.text = @"N/A";
    self.gpsLabel.text = @"GPS: 0";
    self.vsLabel.text = @"VS: 0.0 M/S";
    self.hsLabel.text = @"HS: 0.0 M/S";
    self.altitudeLabel.text = @"Alt: 0 M";
    self.batteryPercentage.text = @"100";
    
    self.myColorBlue = [UIColor colorWithRed:45/255.0 green:188/255.0 blue:220/255.0 alpha:1.0];
    self.myColorGreen = [UIColor colorWithRed:104/255.0 green:175/255.0 blue:97/255.0 alpha:1.0];
    
    //Button Side Navigation
    self.gsButtonVC = [[DJIGSButtonViewController alloc] initWithNibName:@"DJIGSButtonViewController" bundle:[NSBundle mainBundle]];
    [self.gsButtonVC.view setFrame:CGRectMake(0, self.topBarView.frame.origin.y + self.topBarView.frame.size.height+300, self.gsButtonVC.view.frame.size.width, self.gsButtonVC.view.frame.size.height)];
    self.gsButtonVC.delegate = self;
    
    [self.view addSubview:self.gsButtonVC.view];
    
    //GPS Waypoint Configuration
    self.waypointConfigVC = [[DJIWaypointConfigViewController alloc] initWithNibName:@"DJIWaypointConfigViewController" bundle:[NSBundle mainBundle]];
    self.waypointConfigVC.view.alpha = 0;
    self.waypointConfigVC.view.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin;
    
    CGFloat configVCOriginX = (CGRectGetWidth(self.view.frame) - CGRectGetWidth(self.waypointConfigVC.view.frame))/2;
    CGFloat configVCOriginY = CGRectGetHeight(self.topBarView.frame) + CGRectGetMinY(self.topBarView.frame) + 8;
    
    [self.waypointConfigVC.view setFrame:CGRectMake(configVCOriginX, configVCOriginY, CGRectGetWidth(self.waypointConfigVC.view.frame), CGRectGetHeight(self.waypointConfigVC.view.frame))];
    
    //Check if it's using iPad and center the config view
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
        self.waypointConfigVC.view.center = self.view.center;
    }
    //if using a iPhone, center Waypoint View Controller
    else if ( [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        self.waypointConfigVC.view.center = self.view.center;
    }

    self.waypointConfigVC.delegate = self;
    [self.view addSubview:self.waypointConfigVC.view];
    
    //status bar coloring
    self.topBarView.barTintColor = self.myColorBlue;
    self.modeLabel.textColor = [UIColor whiteColor];
    self.gpsLabel.textColor = [UIColor whiteColor];
    self.hsLabel.textColor = [UIColor whiteColor];
    self.vsLabel.textColor = [UIColor whiteColor];
    self.altitudeLabel.textColor = [UIColor whiteColor];
    self.navigationItem.titleView = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"thorbar.png"]];
    
    //initialize battery graphic
    self.batterySymbol.backgroundColor = self.myColorGreen;
    self.batteryBorder.image = [UIImage imageNamed:@"battery.png"];
    
}

- (void)initDrone
{
    self.phantomDrone = [[DJIDrone alloc] initWithType:DJIDrone_Phantom3Professional];
    self.phantomDrone.delegate = self;
    
    self.navigationManager = self.phantomDrone.mainController.navigationManager;
    self.navigationManager.delegate = self;
    
    self.phantomProMainController = (DJIPhantom3ProMainController *)self.phantomDrone.mainController;
    self.phantomProMainController.mcDelegate = self;
    
    self.waypointMission = self.navigationManager.waypointMission;
    
    self.batteryInfo = [[DJIBattery alloc]init];
    
    [self registerApp];
}

- (void)registerApp
{

    NSString *appKey = @"ae1ba4d5b0c6ce707e4ecc6d";
    [DJIAppManager registerApp:appKey withDelegate:self];
}

//Display a UI Alert Controller with specified parameters
-(void)displayAlertWithMessage:(NSString*)message
                      andTitle:(NSString*)title
                      withActionOK:(NSString*)OK
                      withActionCancel:(NSString*)Cancel
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    if(OK != nil) {
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:OK style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {}];
        [alert addAction:okAction];
    }
    if(Cancel != nil) {
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:Cancel style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {}];
        [alert addAction:cancelAction];
    }
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)focusMap
{
    //change to self.droneLocation, when connecting to Drone
    //otherwise, use self.userLocation
    if(CLLocationCoordinate2DIsValid(self.droneLocation)) {
        //For 3D maps, center location by camera, rather than region
        self.mapCamera.centerCoordinate = self.droneLocation;
        self.mapCamera.pitch = 45;
        self.mapCamera.heading = 45;
        self.mapCamera.altitude = 250;
        [self.mapView setCamera:self.mapCamera animated:NO];
    }
    else if(CLLocationCoordinate2DIsValid(self.userLocation) && !CLLocationCoordinate2DIsValid(self.droneLocation)) {
        self.mapCamera.centerCoordinate = self.userLocation;
        self.mapCamera.pitch = 45;
        self.mapCamera.heading = 45;
        self.mapCamera.altitude = 250;
        [self.mapView setCamera:self.mapCamera animated:NO];
    }
}

-(void) hideProgressView
{
    if (self.uploadProgressView) {
        [self.uploadProgressView dismissWithClickedButtonIndex:-1 animated:YES];
        self.uploadProgressView = nil;
    }
}

#pragma mark DJIAppManagerDelegate Method
-(void)appManagerDidRegisterWithError:(int)error
{
    NSString* message = @"Register App Successed!";
    if (error != RegisterSuccess) {
        message = @"Register App Failed! Please enter your App Key and check the network.";
    }else
    {
        [self.phantomDrone connectToDrone];
        [self.phantomDrone.mainController startUpdateMCSystemState];
    }
    [self displayAlertWithMessage:message andTitle:@"Register App" withActionOK:@"OK" withActionCancel:nil];
}

#pragma mark CLLocation Methods
-(void) startUpdateLocation
{
    if ([CLLocationManager locationServicesEnabled]) {
        if (self.locationManager == nil) {
            self.locationManager = [[CLLocationManager alloc] init];
            self.locationManager.delegate = self;
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
            self.locationManager.distanceFilter = 0.1;
            if ([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
                [self.locationManager requestAlwaysAuthorization];
            }
            [self.locationManager startUpdatingLocation];
        }
    }else
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Location Service is not available" message:@"" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    }
}

//Check if user placed waypoint is within range of the user
-(BOOL)waypointOutOfRange:(CGPoint) point
{
    CLLocationCoordinate2D coordinate = [self.mapView convertPoint:point toCoordinateFromView:self.mapView];
    CLLocation *location = [[CLLocation alloc]initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
    CLLocation *userLocationTemp = [[CLLocation alloc]initWithLatitude:self.userLocation.latitude longitude:self.userLocation.longitude];
    CLLocationDistance meters = [location distanceFromLocation:userLocationTemp];
    if(meters < 1000) {
        return YES;
    }
    else {
        [self displayAlertWithMessage:@"Place Closer Waypoint" andTitle:@"Waypoint Out of Range" withActionOK:@"OK" withActionCancel:nil];
        return NO;
    }
}

#pragma mark UITapGestureRecognizer Methods
- (void)addWaypoints:(UITapGestureRecognizer *)tapGesture
{
    CGPoint point = [tapGesture locationInView:self.mapView];
    if(tapGesture.state == UIGestureRecognizerStateEnded){
        if (self.isEditingPoints) {
            if([self waypointOutOfRange:point]) {
                [self.mapController addPoint:point withMapView:self.mapView];
            }
        }
        
    }

}

#pragma mark - DJINavigationDelegate

-(void) onNavigationMissionStatusChanged:(DJINavigationMissionStatus*)missionStatus
{
    
}

#pragma mark - GroundStationDelegate

-(void) groundStation:(id<DJIGroundStation>)gs didExecuteWithResult:(GroundStationExecuteResult*)result
{
    if (result.currentAction == GSActionStart) {
        if (result.executeStatus == GSExecStatusFailed) {
            [self hideProgressView];
            NSLog(@"Mission Start Failed...");
        }
    }
    if (result.currentAction == GSActionUploadTask) {
        if (result.executeStatus == GSExecStatusFailed) {
            [self hideProgressView];
            NSLog(@"Upload Mission Failed");
        }
    }
}

-(void) groundStation:(id<DJIGroundStation>)gs didUploadWaypointMissionWithProgress:(uint8_t)progress
{
    if (self.uploadProgressView == nil) {
        self.uploadProgressView = [[UIAlertView alloc] initWithTitle:@"Mission Uploading" message:@"" delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
        [self.uploadProgressView show];
    }
    
    NSString* message = [NSString stringWithFormat:@"%d%%", progress];
    [self.uploadProgressView setMessage:message];
}

#pragma mark - DJIWaypointConfigViewControllerDelegate Methods

- (void)cancelBtnActionInDJIWaypointConfigViewController:(DJIWaypointConfigViewController *)waypointConfigVC
{
    __weak DJIRootViewController *weakSelf = self;
    
    [UIView animateWithDuration:0.25 animations:^{
        weakSelf.waypointConfigVC.view.alpha = 0;
    }];
    
}

- (void)finishBtnActionInDJIWaypointConfigViewController:(DJIWaypointConfigViewController *)waypointConfigVC
{
    __weak DJIRootViewController *weakSelf = self;
    
    [UIView animateWithDuration:0.25 animations:^{
        weakSelf.waypointConfigVC.view.alpha = 0;
    }];
    
    for (int i = 0; i < self.waypointMission.waypointCount; i++) {
        DJIWaypoint* waypoint = [self.waypointMission waypointAtIndex:i];
        waypoint.altitude = [self.waypointConfigVC.altitudeTextField.text floatValue];
    }
    
    //Setting entered parameters to be uploaded from WaypointController into a "WaypointMission"
    //Waypoint Missions are uploaded to drone
    self.waypointMission.maxFlightSpeed = [self.waypointConfigVC.maxFlightSpeedTextField.text floatValue];
    self.waypointMission.autoFlightSpeed = [self.waypointConfigVC.autoFlightSpeedTextField.text floatValue];
    
    //Heading Mode during mission
    self.waypointMission.headingMode = (DJIWaypointMissionHeadingMode)self.waypointConfigVC.headingSegmentedControl.selectedSegmentIndex;
    
    //Should select Go Home or None right now
    self.waypointMission.finishedAction = (DJIWaypointMissionFinishedAction)self.waypointConfigVC.actionSegmentedControl.selectedSegmentIndex;
    
    //The drone will move from waypoint to waypoint in a straight line
    self.waypointMission.flightPathMode = DJIWaypointMissionFlightPathNormal;
    
    if (self.waypointMission.isValid) {
        
        if (weakSelf.uploadProgressView == nil) {
            weakSelf.uploadProgressView = [[UIAlertView alloc] initWithTitle:@"" message:@"" delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
            [weakSelf.uploadProgressView show];
        }

        [self.waypointMission setUploadProgressHandler:^(uint8_t progress) {
            
            [weakSelf.uploadProgressView setTitle:@"Mission Uploading"];
            NSString* message = [NSString stringWithFormat:@"%d%%", progress];
            [weakSelf.uploadProgressView setMessage:message];
            
        }];

        [self.waypointMission uploadMissionWithResult:^(DJIError *error) {

            [weakSelf.uploadProgressView setTitle:@"Mission Upload Finished"];

            if (error.errorCode != ERR_Succeeded) {
                [weakSelf.uploadProgressView setMessage:@"Mission Invalid!"];
            }
            
            [weakSelf.waypointMission setUploadProgressHandler:nil];
            [weakSelf performSelector:@selector(hideProgressView) withObject:nil afterDelay:3.0];
            
            [weakSelf.waypointMission startMissionWithResult:^(DJIError *error) {
                if (error.errorCode != ERR_Succeeded) {
                    UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Start Mission Failed" message:error.errorDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [alertView show];
                }
            }];
            
        }];

    }else
    {
        UIAlertView *invalidMissionAlert = [[UIAlertView alloc] initWithTitle:@"Waypoint mission invalid" message:@"" delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [invalidMissionAlert show];
    }
    
}

#pragma mark - DJIGSButtonViewController Delegate Methods

- (void)stopBtnActionInGSButtonVC:(DJIGSButtonViewController *)GSBtnVC
{
    [self.waypointMission stopMissionWithResult:^(DJIError *error) {
        
        if (error.errorCode == ERR_Succeeded) {
            UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Stop Mission Success" message:@"" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alertView show];
        }

    }];

}

- (void)clearBtnActionInGSButtonVC:(DJIGSButtonViewController *)GSBtnVC
{
    [self.mapController cleanAllPointsWithMapView:self.mapView];
}

- (void)focusMapBtnActionInGSButtonVC:(DJIGSButtonViewController *)GSBtnVC
{
    [self focusMap];
}

- (void)configBtnActionInGSButtonVC:(DJIGSButtonViewController *)GSBtnVC
{
    __weak DJIRootViewController *weakSelf = self;
    
    NSArray* wayPoints = self.mapController.wayPoints;
    if (wayPoints == nil || wayPoints.count < DJIWaypointMissionMinimumWaypointCount) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No or not enough waypoint for mission" message:@"" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    /***********
     Safety Checks before takeoff/User can enter flight parameters
     Comment out when testing with Simulation
     1. Must have greater than 6 satellites locked in
     2. GPS Signal should be 2 or above in order for it to go home after mission is finished
     3. Battery level should be above 40% for a mission
     ********/
    
    /***
    if(self.gpsSatelliteCount < 6) {
        NSString *message = @"Not enough satellites locked in for safe flight";
        NSString *title = @"Not enough satellites locked in for safe flight";
        [self displayAlertWithMessage:message andTitle:title withActionOK:@"OK" withActionCancel:nil];
        return;
    }
    if(self.gpsSignalLevel == GpsSignalLevel0 && self.gpsSignalLevel == GpsSignalLevel1) {
        NSString *message = @"Retry when stronger signal";
        NSString *title = @"Weak GPS Signal";
        [self displayAlertWithMessage:message andTitle:title withActionOK:@"OK" withActionCancel:nil];
        return;
    }
    if(self.batteryInfo.remainPowerPercent < 40) {
        NSString *message = @"Battery Level 40%, Recharge for Mission";
        NSString *title = @"Insufficient Battery Level";
        [self displayAlertWithMessage:message andTitle:title withActionOK:@"OK" withActionCancel:@"Cancel"];
    }
    if(self.powerLevel < 2) {
        NSString *message = @"Power Level Below 2, Recharge for Mission";
        NSString *title = @"Insufficient Power Level";
        [self displayAlertWithMessage:message andTitle:title withActionOK:@"OK" withActionCancel:nil];
    }
     ***/
    
    [UIView animateWithDuration:0.25 animations:^{
        weakSelf.waypointConfigVC.view.alpha = 1.0;
    }];
    
    [self.waypointMission removeAllWaypoints];

    for (int i = 0; i < wayPoints.count; i++) {
        CLLocation* location = [wayPoints objectAtIndex:i];
        if (CLLocationCoordinate2DIsValid(location.coordinate)) {
            DJIWaypoint* waypoint = [[DJIWaypoint alloc] initWithCoordinate:location.coordinate];
            [self.waypointMission addWaypoint:waypoint];
        }
    }
    
}

- (void)startBtnActionInGSButtonVC:(DJIGSButtonViewController *)GSBtnVC
{
    [self.waypointMission startMissionWithResult:^(DJIError *error) {
        if (error.errorCode != ERR_Succeeded) {
            UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Start Mission Failed" message:error.errorDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alertView show];
        }
    }];
}

- (void)switchToMode:(DJIGSViewMode)mode inGSButtonVC:(DJIGSButtonViewController *)GSBtnVC
{
    if (mode == DJIGSViewMode_EditMode) {
        [self focusMap];
    }
    
}

- (void)addBtn:(UIButton *)button withActionInGSButtonVC:(DJIGSButtonViewController *)GSBtnVC
{
    if (self.isEditingPoints) {
        self.isEditingPoints = NO;
        [button setTitle:@"Add" forState:UIControlStateNormal];
    }else
    {
        self.isEditingPoints = YES;
        [button setTitle:@"Finished" forState:UIControlStateNormal];
    }
}

#pragma mark - CLLocationManagerDelegate
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    CLLocation* location = [locations lastObject];
    self.userLocation = location.coordinate;
}

#pragma mark MKMapViewDelegate Method
- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MKPointAnnotation class]]) {
        MKPinAnnotationView* pinView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"Pin_Annotation"];
        pinView.pinTintColor = self.myColorBlue;
        return pinView;
        
    }else if ([annotation isKindOfClass:[DJIAircraftAnnotation class]])
    {
        DJIAircraftAnnotationView* annoView = [[DJIAircraftAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"Aircraft_Annotation"];
        ((DJIAircraftAnnotation*)annotation).annotationView = annoView;
        return annoView;
    }
    
    return nil;
}

- (void)enterNavigationMode
{
    [self.navigationManager enterNavigationModeWithResult:^(DJIError *error) {
        if (error.errorCode != ERR_Succeeded) {
            NSString* message = [NSString stringWithFormat:@"Enter navigation mode failed:%@", error.errorDescription];
            UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Enter Navigation Mode" message:message delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Retry", nil];
            alertView.tag = kEnterNaviModeFailedAlertTag;
            [alertView show];
        }
        else
        {
            NSString* message = @"Enter navigation mode Success";
            UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Enter Navigation Mode" message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alertView show];
            
        }
    }];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == kEnterNaviModeFailedAlertTag) {
        if (buttonIndex == 1) {
            [self enterNavigationMode];
        }
    }
}

#pragma mark - DJIDroneDelegate Method
-(void) droneOnConnectionStatusChanged:(DJIConnectionStatus)status
{
    if (status == ConnectionSucceeded) {
        [self enterNavigationMode];
    }
}

#pragma mark - DJIMainControllerDelegate Method

-(void) mainController:(DJIMainController*)mc didUpdateSystemState:(DJIMCSystemState*)state
{
    self.droneLocation = state.droneLocation;
    
    if (!state.isMultipleFlightModeOpen) {
        [self.phantomProMainController setMultipleFlightModeOpen:YES withResult:nil];
    }
    
    //not returning battery info
//    [self.batteryInfo updateBatteryInfo:^(DJIError *error) {
//        if(error.errorCode == ERR_Succeeded) {
//            self.batteryPercentage.text = [NSString stringWithFormat:@"%ld", (long)self.batteryInfo.remainPowerPercent];
//        }
//        if(error.errorCode != ERR_Succeeded) {
//            [self displayAlertWithMessage:@"batteryInfo not retrieved" andTitle:@"battery info" withActionOK:@"OK" withActionCancel:nil];
//        }
//    }];
    
    self.modeLabel.text = state.flightModeString;
    self.gpsLabel.text = [NSString stringWithFormat:@"GPS: %d", state.satelliteCount];
    self.vsLabel.text = [NSString stringWithFormat:@"VS: %0.1f M/S",state.velocityZ];
    self.hsLabel.text = [NSString stringWithFormat:@"HS: %0.1f M/S",(sqrtf(state.velocityX*state.velocityX + state.velocityY*state.velocityY))];
    self.altitudeLabel.text = [NSString stringWithFormat:@"Alt: %0.1f M",state.altitude];
    
    //Pre Launch important variable checks
    self.gpsSatelliteCount = state.satelliteCount;
    self.powerLevel = state.powerLevel;
    self.batteryPercentage.text = [NSString stringWithFormat:@"%i", self.powerLevel];
    self.gpsSignalLevel = state.gpsSignalLevel;
    
    [self.mapController updateAircraftLocation:self.droneLocation withMapView:self.mapView];
    double radianYaw = (state.attitude.yaw * M_PI / 180.0);
    [self.mapController updateAircraftHeading:radianYaw];
    
}

@end