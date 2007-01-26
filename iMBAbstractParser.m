/*
 
 Permission is hereby granted, free of charge, to any person obtaining a 
 copy of this software and associated documentation files (the "Software"), 
 to deal in the Software without restriction, including without limitation 
 the rights to use, copy, modify, merge, publish, distribute, sublicense, 
 and/or sell copies of the Software, and to permit persons to whom the Software 
 is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in 
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS 
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
 AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 iMedia Browser Home Page: <http://imedia.karelia.com/>
 
 Please send fixes to <imedia@lists.karelia.com>

*/

#import "iMBAbstractParser.h"
#import "UKKQueue.h"
#import "iMBLibraryNode.h"
#import "NSAttributedString+iMedia.h"


#warning TODO: we should split the UKKQue stuff into a new abstract subclass of this, for better encapsulation since many subclasses don't need UKKQueue.




@implementation iMBAbstractParser

- (id)init
{
	if (self = [super init])
	{
		
	}
	return self;
}

- (id)initWithContentsOfFile:(NSString *)file
{
	if (self = [super init])
	{
		myDatabase = [file copy];
		myFileWatcher = [[UKKQueue alloc] init];
		[myFileWatcher setDelegate:self];
		if (file)
		{
			[myFileWatcher addPath:myDatabase];
		}
	}
	return self;
}

- (void)dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[myFileWatcher setDelegate:nil];
	[myFileWatcher release];
	[myDatabase release];
	[myCachedLibrary release];
	[super dealloc];
}

- (iMBLibraryNode *)library:(BOOL)reuseCachedData
{
	if (!myCachedLibrary || !reuseCachedData)
	{
      [myCachedLibrary release];
		myCachedLibrary = [[self parseDatabase] retain];
	}
	return myCachedLibrary;
}

- (iMBLibraryNode *)parseDatabase
{
	// we do nothing, let the subclass do the hard yards.
	return nil;
}

- (void)setBrowser:(id <iMediaBrowser>)browser
{
	myBrowser = browser;
}

- (NSString *)databasePath
{
	return myDatabase;
}

- (void)watchFile:(NSString *)file
{
	[myFileWatcher addPath:file];
}

- (void)stopWatchingFile:(NSString *)file
{
	[myFileWatcher removePath:file];
}

- (NSAttributedString *)name:(NSString *)name withImage:(NSImage *)image
{
	return [NSAttributedString attributedStringWithName:name image:image];
}

#pragma mark -
#pragma mark UKKQueue Delegate Methods

-(void) doReparseLater
{
	[NSThread detachNewThreadSelector:@selector(threadedParseDatabase)
							 toTarget:self
						   withObject:nil];
}

-(void) watcher:(id<UKFileWatcher>)kq receivedNotification:(NSString*)nm forPath:(NSString*)fpath
{
	/*
	UKKQueue will often send 3 or 4 notifications per change. There is no point in us reparsing each time
	so we delay the reparse for a short while so we can ignore all but the last one.
	*/
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(doReparseLater) object:nil];
	[self performSelector:@selector(doReparseLater) withObject:nil afterDelay:0.2];
}

- (void)threadedParseDatabase
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	iMBLibraryNode *newDB = [self parseDatabase];
	
	[myCachedLibrary removeAllItems];
	[myCachedLibrary setItems:[newDB items]];
	[myCachedLibrary setAttributes:[newDB attributes]];
	
	// need to notify the browser that our data changed so it can refresh the outline view
	[(NSObject *)myBrowser performSelectorOnMainThread:@selector(refresh)
											withObject:nil
										 waitUntilDone:YES];
	
	[pool release];
}

@end
