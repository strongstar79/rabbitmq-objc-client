#import "RMQPKCS12CertificateConverter.h"
#import "RMQConstants.h"

@interface RMQPKCS12CertificateConverter ()
@property (nonatomic, readwrite) NSData *data;
@property (nonatomic, readwrite) NSString *password;
@end

@implementation RMQPKCS12CertificateConverter

- (instancetype)initWithData:(NSData *)data
                    password:(NSString *)password {
    self = [super init];
    if (self) {
        self.data = data;
        self.password = password;
    }
    return self;
}

- (NSArray *)certificatesWithError:(NSError *__autoreleasing *)error {
    SecIdentityRef identity;
    [self parseIdentity:self.data identity:&identity error:error];

    if (*error) {
        return nil;
    } else {
        return @[(__bridge id)identity];
    }
}

# pragma mark - Private

- (void)parseIdentity:(NSData *)data identity:(SecIdentityRef *)identity error:(NSError **)error {
    CFDataRef cfData = (__bridge CFDataRef)data;
    OSStatus status = errSecSuccess;
    NSDictionary *options = @{ (__bridge NSString*)kSecImportExportPassphrase : self.password };
    CFArrayRef items = CFArrayCreate(NULL, 0, 0, NULL);
    status = SecPKCS12Import(cfData, (__bridge CFDictionaryRef)options, &items);

    switch (status) {
        case errSecSuccess:
            *identity = (SecIdentityRef)CFDictionaryGetValue(CFArrayGetValueAtIndex(items, 0),
                                                             kSecImportItemIdentity);
            break;

        case errSecAuthFailed:
            *error = [NSError errorWithDomain:RMQErrorDomain
                                         code:RMQConnectionErrorTLSCertificateAuthFailure
                                     userInfo:@{NSLocalizedDescriptionKey: @"TLS certificate authentication failed. Incorrect password?"}];
            break;

        case errSecDecode:
            *error = [NSError errorWithDomain:RMQErrorDomain
                                         code:RMQConnectionErrorTLSCertificateDecodeError
                                     userInfo:@{NSLocalizedDescriptionKey: @"TLS certificate decoding error. Corrupt PKCS12 data?"}];
            break;

        default:
            break;
    }
}

@end
