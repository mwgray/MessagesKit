/*
   Licensed under the MIT License

   Copyright (c) 2011 Cédric Luthi

   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
   THE SOFTWARE.
 */

#import "NSData+CommonDigest.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSData (CommonDigest)

static NSData* digest(NSData *data, unsigned char * (*cc_digest)(const void *, CC_LONG, unsigned char *), CC_LONG digestLength)
{
  unsigned char md[digestLength];
  (void)cc_digest([data bytes], (CC_LONG)[data length], md);
  return [NSData dataWithBytes:md length:digestLength];
}

// MARK: Message-Digest Algorithm

-(NSData *) md2
{
  return digest(self, CC_MD2, CC_MD2_DIGEST_LENGTH);
}

-(NSData *) md4
{
  return digest(self, CC_MD4, CC_MD4_DIGEST_LENGTH);
}

-(NSData *) md5
{
  return digest(self, CC_MD5, CC_MD5_DIGEST_LENGTH);
}

// MARK: Secure Hash Algorithm

-(NSData *) sha1
{
  return digest(self, CC_SHA1, CC_SHA1_DIGEST_LENGTH);
}

-(NSData *) sha224
{
  return digest(self, CC_SHA224, CC_SHA224_DIGEST_LENGTH);
}

-(NSData *) sha256
{
  return digest(self, CC_SHA256, CC_SHA256_DIGEST_LENGTH);
}

-(NSData *) sha384
{
  return digest(self, CC_SHA384, CC_SHA384_DIGEST_LENGTH);
}

-(NSData *) sha512
{
  return digest(self, CC_SHA512, CC_SHA512_DIGEST_LENGTH);
}

@end
