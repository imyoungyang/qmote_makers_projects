/*
 * Copyright (c) 2015
 * Qblinks Corporation.
 * All rights reserved.
 *
 * The information contained herein is confidential and proprietary to
 * Qblinks. Use of this information by anyone other than authorized employees
 * of Qblinks is granted only under a written non-disclosure agreement,
 * expressly prescribing the scope and manner of such use.
 *
 */

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    _QPS_ServiceUUID = [CBUUID UUIDWithString:QPS_Q1_SERVICE_UUID];
    _QPS_BTN_CharacterUUID = [CBUUID UUIDWithString:QPS_Q1_BTN_UUID];
    _QPS_CMD_CharacterUUID = [CBUUID UUIDWithString:QPS_Q1_CMD_UUID];
    _QPS_CB_CharacterUUID = [CBUUID UUIDWithString:QPS_Q1_CB_UUID];
    
    self.CM = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
 * Show iOS BT status
 */
- (const char *) centralManagerStateToString: (int)state{
    switch(state) {
        case CBCentralManagerStateUnknown:
            return "State unknown (CBCentralManagerStateUnknown)";
        case CBCentralManagerStateResetting:
            return "State resetting (CBCentralManagerStateUnknown)";
        case CBCentralManagerStateUnsupported:
            return "State BLE unsupported (CBCentralManagerStateResetting)";
        case CBCentralManagerStateUnauthorized:
            return "State unauthorized (CBCentralManagerStateUnauthorized)";
        case CBCentralManagerStatePoweredOff:
            return "State BLE powered off (CBCentralManagerStatePoweredOff)";
        case CBCentralManagerStatePoweredOn:
            return "State powered up and ready (CBCentralManagerStatePoweredOn)";
        default:
            return "State unknown";
    }
    return "Unknown state";
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central{
    const char *c = [self centralManagerStateToString:central.state];
    NSLog(@"Status of CoreBluetooth central manager changed %ld (%s)", (long)central.state, c);
    
    if(central.state == CBCentralManagerStatePoweredOn)
        NSLog(@"BLE ready.");
}

- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary *)state{
    NSLog(@"CBCentralManager willRestoreState");
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{
    NSLog(@"didConnectPeripheral with UUID : %@ successfully",[peripheral.identifier UUIDString]);
    
    CBUUID  *serviceUUID2    = [CBUUID UUIDWithString:QPS_Q1_SERVICE_UUID];
    CBUUID  *serviceUUID3    = [CBUUID UUIDWithString:@"0x180A"];
    NSArray *serviceArray   = [NSArray arrayWithObjects: serviceUUID2, serviceUUID3, nil];
    
    peripheral.delegate = self;
    [peripheral discoverServices:serviceArray];
}

- (void) centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Connection failed to peripheral: %@ with UUID: %@",peripheral, [peripheral.identifier UUIDString]);
    NSLog(@"Attempted connection to peripheral %@ failed: %@", [peripheral name], [error localizedDescription]);
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if( peripheral.identifier == NULL)
        return;
    
    if (!error)
    {
        for (CBService *service in peripheral.services)
        {
            NSLog(@"Service found with UUID: %@", service.UUID);
            if ([service.UUID.data isEqualToData:_QPS_ServiceUUID.data])
            {
                NSLog(@"discoveryCharacteristics...%@", _QPS_ServiceUUID);
                [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:QPS_Q1_BTN_UUID], [CBUUID UUIDWithString:QPS_Q1_CMD_UUID], [CBUUID UUIDWithString:QPS_Q1_CB_UUID]] forService:service];
            }
        }
    }
    else
    {
        NSLog(@"Service discovery was unsuccessfull !");
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    NSLog(@"didDiscoverCharacteristicsForService...%@", [peripheral.identifier UUIDString]);
    CBService *s = [peripheral.services objectAtIndex:(peripheral.services.count - 1)];
    CBCharacteristic *_QPS_point = nil;
    
    if (!error)
    {
        if(service.UUID == NULL || s.UUID == NULL)
            return;
        
        CBCharacteristic *_QPS_CMD_Characteristic = nil;
        CBCharacteristic *_QPS_BTN_Characteristic = nil;
        CBCharacteristic *_QPS_CB_Characteristic = nil;
        
        if ([service.UUID.data isEqualToData:_QPS_ServiceUUID.data])
        {
            _QPS_BTN_Characteristic = [self findCharacteristics:service.characteristics uuid:_QPS_BTN_CharacterUUID];
            _QPS_CB_Characteristic = [self findCharacteristics:service.characteristics uuid:_QPS_CB_CharacterUUID];
            _QPS_CMD_Characteristic = [self findCharacteristics:service.characteristics uuid:_QPS_CMD_CharacterUUID];
            _QPS_point = _QPS_CMD_Characteristic;
            
            [peripheral setNotifyValue:YES forCharacteristic:_QPS_BTN_Characteristic];
            [peripheral setNotifyValue:YES forCharacteristic:_QPS_CB_Characteristic];
            [peripheral readValueForCharacteristic:_QPS_CB_Characteristic];
            
            _click_label.text = @"Connected";
            [self Send_CMD2_Qmote];
        }
        
        if([self compareCBUUID:service.UUID UUID2:s.UUID])
        {
            if(peripheral && [peripheral state] == CBPeripheralStateConnected)
                NSLog(@"Already connected");
            else
                NSLog(@"compareCBUUID faild.\r\n");
        }
    }
    else
        NSLog(@"error:%@", [error description]);
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:
(NSError *)error{
    
    /* F-code list
     * [Release] 0x00
     * .         0x01
     * ..        0x02
     * ...       0x03
     * ....      0x04
     * -.        0x05
     * .-.       0x06
     * --.       0x07
     * -..       0x08
     * -...      0x09
     * --..      0x0A
     * ---.      0x0B
     */
    
    char keys;
    
    NSLog(@"didUpdateValueForCharacteristic....%@[%@]", [peripheral.identifier UUIDString], characteristic);
    
    if([characteristic.UUID isEqual:[CBUUID UUIDWithString:QPS_Q1_BTN_UUID]]){
        [characteristic.value getBytes:&keys length:1];
        if(keys != 0x0){ //0x0 is buttone release code
            switch (keys) {
                case 1:
                    _click_label.text =[NSString stringWithFormat:@"Click .(%02X)", keys];
                    break;
                case 2:
                    _click_label.text =[NSString stringWithFormat:@"Click ..(%02X)", keys];
                    break;
                case 3:
                    _click_label.text =[NSString stringWithFormat:@"Click ...(%02X)", keys];
                    break;
                case 4:
                    _click_label.text =[NSString stringWithFormat:@"Click ....(%02X)", keys];
                    break;
                case 5:
                    _click_label.text =[NSString stringWithFormat:@"Click -.(%02X)", keys];
                    break;
                case 6:
                    _click_label.text =[NSString stringWithFormat:@"Click .-.(%02X)", keys];
                    break;
                case 7:
                    _click_label.text =[NSString stringWithFormat:@"Click --.(%02X)", keys];
                    break;
                case 8:
                    _click_label.text =[NSString stringWithFormat:@"Click -..(%02X)", keys];
                    break;
                case 9:
                    _click_label.text =[NSString stringWithFormat:@"Click -...(%02X)", keys];
                    break;
                case 10:
                    _click_label.text =[NSString stringWithFormat:@"Click --..(%02X)", keys];
                    break;
                case 11:
                    _click_label.text =[NSString stringWithFormat:@"Click ---.(%02X)", keys];
                    break;
                    
                default:
                    break;
            }
        }
    } else if([characteristic.UUID isEqual:[CBUUID UUIDWithString:QPS_Q1_CB_UUID]]) {
        unsigned char value[4];
        [characteristic.value getBytes:&value length:sizeof(value)];
        
        /* Check first 2 bytes of return header is device info type */
        if (value[0] == 0x06 && value[1] == 0x07) {
            NSString *version = [[NSString alloc] initWithData:[characteristic.value subdataWithRange:NSMakeRange(2, characteristic.value.length - 2)] encoding:NSUTF8StringEncoding];
            UIAlertView *fwversion_alert = [[UIAlertView alloc] initWithTitle:@"Qmote FW Version"
                                                                      message:version
                                                                     delegate:self
                                                            cancelButtonTitle:nil
                                                            otherButtonTitles:@"OK", nil];
            [fwversion_alert show];

        }
    }
}

-(CBCharacteristic *)findCharacteristics:(NSArray *)cs uuid:(CBUUID *)uuid
{
    for (CBCharacteristic *c in cs) {
        if ([c.UUID.data isEqualToData:uuid.data]) {
            NSLog(@"\tUUID:%@ value:%@ (uuid:%@)", c.UUID, c.value, uuid.data);
            return c;
        }
    }
    return nil;
}

-(BOOL) compareCBUUID:(CBUUID *) UUID1 UUID2:(CBUUID *)UUID2 {
    char b1[16];
    char b2[16];
    [UUID1.data getBytes:b1 length:16];
    [UUID2.data getBytes:b2 length:16];
    if (memcmp(b1, b2, UUID1.data.length) == 0)
        return TRUE;
    else
        return FALSE;
}

-(CBService *) findServiceFromUUID:(CBUUID *)UUID p:(CBPeripheral *)p {
    for(int i = 0; i < p.services.count; i++) {
        CBService *s = [p.services objectAtIndex:i];
        if ([self compareCBUUID:s.UUID UUID2:UUID]) return s;
    }
    return nil; //Service not found on this peripheral
}

-(CBCharacteristic *) findCharacteristicFromUUID:(CBUUID *)UUID service:(CBService*)service {
    for(int i=0; i < service.characteristics.count; i++) {
        CBCharacteristic *c = [service.characteristics objectAtIndex:i];
        if ([self compareCBUUID:c.UUID UUID2:UUID]) return c;
    }
    return nil; //Characteristic not found on this service
}

- (IBAction)connect_btn_click:(id)sender {
    
    CBUUID *s1 = [CBUUID UUIDWithString:QPS_Q1_SERVICE_UUID];
    NSArray *service_list = [[NSArray alloc] initWithObjects:s1, nil];
    _Qmote_list = [_CM retrieveConnectedPeripheralsWithServices:service_list]; /* Get Qmote list connected and paired in system setting */
    
    if([_Qmote_list count])
    {
        _Qmote_p = [_Qmote_list objectAtIndex:0]; /* Connect the first Qmote in system setting */
        [_CM connectPeripheral:_Qmote_p options:nil]; //Connect Qmote
    }
    
}

/* 
 * If App want to enable long press, Qmote firmware need get a long press F-code setting.
 * This function send a 0x06(.-.) for F_APP_DEF, it will let Qmote long press enable.
 */
-(void)Send_CMD2_Qmote {
    
    NSData *expectedData = nil;
    unsigned char bytes[] = {0x10, 0x06, F_APP_DEF};
    expectedData = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    
    CBUUID *su = [CBUUID UUIDWithString:QPS_Q1_SERVICE_UUID];
    CBUUID *cu = [CBUUID UUIDWithString:QPS_Q1_CMD_UUID];
    CBService *service = [self findServiceFromUUID:su p:_Qmote_p];
    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:cu service:service];

    if(characteristic !=nil)
        [_Qmote_p writeValue:expectedData forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
    
}

/* Send keep-alive command to Qmote 
 * 0x2c, 0x01:Keep alive command
 */
-(void)Send_keepalive_Qmote {
    NSData *expectedData = nil;
    unsigned char bytes[] = {0x2c, 0x01};
    expectedData = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    
    CBUUID *su = [CBUUID UUIDWithString:QPS_Q1_SERVICE_UUID];
    CBUUID *cu = [CBUUID UUIDWithString:QPS_Q1_CMD_UUID];
    CBService *service = [self findServiceFromUUID:su p:_Qmote_p];
    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:cu service:service];
    
    if(characteristic !=nil)
        [_Qmote_p writeValue:expectedData forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
}

/* Send a FW version request command to Qmote and your will get the callback event at didUpdateValueForCharacteristic().
 * 0x06, 0x07:Firmware version
 */
-(void)Send_FWversion_Qmote {
    NSData *expectedData = nil;
    unsigned char bytes[] = {0x06, 0x07};
    expectedData = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    
    CBUUID *su = [CBUUID UUIDWithString:QPS_Q1_SERVICE_UUID];
    CBUUID *cu = [CBUUID UUIDWithString:QPS_Q1_CMD_UUID];
    CBService *service = [self findServiceFromUUID:su p:_Qmote_p];
    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:cu service:service];
    
    if(characteristic !=nil)
        [_Qmote_p writeValue:expectedData forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
}

/* User doesn't press Qmote for a few seconds, Qmote will into sleep mode to save power and Qmote will disconnect from iPhone.
 * This keep-alive command will extend the time. If you want Qmote keep waking up, we suggest that send this command every 30 seconds to Qmote in foreground.
 */
- (IBAction)keepalive_touch:(id)sender {
    [self Send_keepalive_Qmote];
}

- (IBAction)fw_version_touch:(id)sender {
    [self Send_FWversion_Qmote];
}
@end