// Atlas Generator
// Ehsan Marufi (c) December 2017

package nibblessoft.atlasGenerator
{
import flash.display.BitmapData;
import flash.display.DisplayObject;
import flash.display.DisplayObjectContainer;
import flash.display.MovieClip;
import flash.filters.BitmapFilter;
import flash.geom.Rectangle;

public class AtlasItem
	{
		private var _target:DisplayObjectContainer;
		
		/**
		 * An identical clone of the <code>_target</code> object, where all the values are preserved
		 * intact to be used as a renference to the original values in an read-only fashion.<hr>
		 * For example, modifying the filters on a MovieClip (say, to have them scaled) discards all
		 * the animations applied to the <code>filters</code> property of the object. Thus, to preserve
		 * all the information whitin the object intact, we need an identical clone of the object only
		 * to <em>read</em> the data from.
		 */
		private var _targetRef:DisplayObjectContainer;
		
		
		private var _isMovieClip:Boolean;
		private var _movieClip:MovieClip;
		private var _scaleX:Number;
		private var _scaleY:Number;
		
		private var _bareBoundingBox:Rectangle;
		private var _fullBoundingBox:Rectangle;
		private var _fullFramesBoundingBox:Rectangle;
		
		private var _currentFrameName:String;
		private var _currentLabel:String;
		private var _currentLabelIndex:uint;
		private var _currentLabelDigitsCount:int;
		
		private var _filtersExtensionTop:int, _filtersExtensionLeft:int;
		
		
		public static const SNAP2PIXELGRID_DEFORMATIONAL:uint = 0;
		public static const SNAP2PIXELGRID_PROPORTIONAL:uint  = 1;
		
		public static const SNAP2PIXELGRID_FLOOR_WIDTH:uint   = 1 << 1;
		public static const SNAP2PIXELGRID_CEIL_WIDTH:uint    = 1 << 2;
		public static const SNAP2PIXELGRID_ROUND_WIDTH:uint   = 1 << 3;
		
		public static const SNAP2PIXELGRID_FLOOR_HEIGHT:uint  = 1 << 4;
		public static const SNAP2PIXELGRID_CEIL_HEIGHT:uint   = 1 << 5;
		public static const SNAP2PIXELGRID_ROUND_HEIGHT:uint  = 1 << 6;
		
		public static const SNAP2PIXELGRID_PROPORTIONAL_BOTH_INTEGER_PREFER_SMALLER:uint = 1 << 7;
		public static const SNAP2PIXELGRID_PROPORTIONAL_BOTH_INTEGER_LARGER:uint         = 1 << 8;
		
		private var _snap2pixelGridOptions:uint;
		
		
		
		private var _traversed:Object;
		
		// TODO: NOT FULLY IMPLEMENTED! It's only partially implemented for the case of being `true`!!
		private var _scaleFilters:Boolean;
		
		private var _rotateFilters:Boolean;

		
		// TO-DOCUMENT: the snapToPixelGridOptions can modify the specified scaleX and/or scaleY
		// TO-DOCUMENT: the snapToPixelGrid with a value of 0, disables the snap operations.

		public function AtlasItem(
			target:DisplayObjectContainer,
			name:String = null,
			scaleX:Number = 1.0,
			scaleY:Number = 1.0,
			scaleFilters:Boolean = true,
			rotateFilters:Boolean = true,
			snapToPixelGridOptions:uint = SNAP2PIXELGRID_PROPORTIONAL | SNAP2PIXELGRID_FLOOR_WIDTH | SNAP2PIXELGRID_FLOOR_HEIGHT)
		{
			_target = target;
			
			/*if (target is FlatShadow)
				_targetRef = (_target as FlatShadow).clone() as DisplayObjectContainer;
			else
				_targetRef = (new (Object(_target).constructor)()) as DisplayObjectContainer;*/
			_targetRef = target;
			
			_traversed = traverseNaryTreePostOrder(_target);
			
			_scaleFilters = scaleFilters;
			_rotateFilters = rotateFilters;
			
			if (name != null)
				_target.name = name;
			
			_isMovieClip = _target is MovieClip;
			_movieClip = _target as MovieClip;
			
			if (_isMovieClip)
				_movieClip.stop();
			
			_scaleX = isNaN(scaleX) ? 1 : scaleX;
			_scaleY = isNaN(scaleY) ? 1 : scaleY;
			
			_currentFrameName = "";
			_currentLabel = "";
			_currentLabelIndex = 0;
			_currentLabelDigitsCount = -1;
			
			_snap2pixelGridOptions = snapToPixelGridOptions;
		}
		
		public function get target():DisplayObject { return _target; }
		
		public function get scaleX():Number { return _scaleX; }
		public function get scaleY():Number { return _scaleY; }
		
		public function get bareBoundingBox():Rectangle { return _bareBoundingBox; }
		public function get fullBoundingBox():Rectangle { return _fullBoundingBox; }
		
		
		/** Provides the bounding box that encompasses all the frames throughout
		 *  the object timeline.*/
		public function get fullFramesBoundingBox():Rectangle { return _fullFramesBoundingBox; }
		
		
		/** After a frame has been prepared (using the methods of <code>prepareFirstFrame()</code>
		 *  or <code>prepareNextFrame()</code>, i.e: the latest label has been determined), the
		 *  nickName of the current frame will be accessible throught this property.<hr>
		 * 
		 *  Name format: [latest label]-[label's FrameIndex]<br>
		 *  e.g: When the latest frame label is "jump" and the timeline is in the fifth frame
		 *  of the animation track, and the course of the "jump" track has a two-digit frames
		 *  count (say, 12 for example), then the frame nickName would be: <code>jump-04</code>.*/
		public function get currentFrameName():String { return _currentFrameName; }
		
		public function get filtersExtensionTop():int { return _filtersExtensionTop; }
		public function get filtersExtensionLeft():int { return _filtersExtensionLeft; }
		
		public function prepareFirstFrame():void
		{
			if (_isMovieClip)
			{
				_fullFramesBoundingBox = getMovieClipFramesBounds();
				_fullBoundingBox = getFullBounds();
			}
			else
			{
				// 'Sprite' objects only have one single frame.
				_fullFramesBoundingBox = getFullBounds();
				_fullBoundingBox = _fullFramesBoundingBox.clone();
			}
			
			prepareCurrentFrame();
		}
		
		public function prepareNextFrame():Boolean
		{
			var b:Boolean = _isMovieClip && _movieClip.currentFrame < _movieClip.totalFrames;
			if (b)
			{
				// The movieClip has some frame waiting to get drawn, so proceed to the next frame 
				_movieClip.nextFrame();
				// update the bounding box for the new frame of the movieClip
				_fullBoundingBox = getFullBounds();
				
				prepareCurrentFrame();
			}
			return b;
		}
		
		private function prepareCurrentFrame():void
		{
			_bareBoundingBox = getBareBounds();
			
			_filtersExtensionTop = _filtersExtensionLeft = 0;
			if (_target.filters.length > 0)
			{
				_filtersExtensionTop = Math.max(_bareBoundingBox.top - _fullBoundingBox.top, 0);
				_filtersExtensionLeft = Math.max(_bareBoundingBox.left - _fullBoundingBox.left, 0);
			}
			
			
			// Update frame nickName
			_currentFrameName = _target.name;
			if (_isMovieClip)
			{
				if (_movieClip.currentFrameLabel && _movieClip.currentFrameLabel != _currentLabel)
				{
					// A new frame label is encountered on the movieClip's timeline
					_currentLabel = _movieClip.currentFrameLabel;
					_currentLabelIndex = 0;
					_currentLabelDigitsCount = -1;
				}
				if (_currentLabelDigitsCount == -1)
					_currentLabelDigitsCount = getCurrentLabelRunFramesCount().toString().length;
				
				_currentFrameName += (_currentLabel != "" ? "-"+_currentLabel : "") + "-" + leadingZerosFormat(_currentLabelIndex++, _currentLabelDigitsCount);
			}
		}
		
		/** When a <em>label</em> is defined on a movieclip frame; the sequence of all the frames 
		 *  that follow until a new <em>label</em> is encountered, is called a <em>label run</em>.<br>
		 *  The method is to be utilized on the movieclips only, otherwise the usage is not
		 *  rational (only movieClips can have multiple frames and 
		 *  ultimatly, the <em>frames label run</em>!)
		 */
		private function getCurrentLabelRunFramesCount():uint
		{
			const initialFrameIndex:int = _movieClip.currentFrame;
			var count:uint = 1;
			for (var i:int = initialFrameIndex; i <= _movieClip.totalFrames; ++i)
			{
				if (_movieClip.currentFrameLabel && _movieClip.currentFrameLabel != _currentLabel)
					break;
				_movieClip.nextFrame();
				count++;
			}
			
			_movieClip.gotoAndStop(initialFrameIndex);
			return count;
		}
		
		private function leadingZerosFormat(n:int, maxDigitsCount:int):String
		{
			var str:String = n.toString();
			if (str.length >= maxDigitsCount)
				return str;
			
			for (var i:uint = str.length; i < maxDigitsCount; ++i)
				str = "0"+str;
			
			return str;
		}
		
		/*private function integralizeRect(rect:Rectangle):Rectangle
		{
			var intX:int = Math.floor(rect.x),
				intY:int = Math.floor(rect.y),
				intW:int = Math.floor(rect.width),
				intH:int = Math.floor(rect.height);
			
			var fracX:Number = Math.abs(rect.x - intX),
				fracY:Number = Math.abs(rect.y - intY),
				fracW:Number = Math.abs(rect.width - intW),
				fracH:Number = Math.abs(rect.height - intH);
			
			rect.x = intX;
			rect.y = intY;
			//rect.width = intW + Math.ceil(fracX + fracW);
			//rect.height = intH + Math.ceil(fracY + fracH);
			
			return rect;
		}*/
		
		/** Gets the boundaries that encompasses the full bounding boxes of all the frames across 
		 *  the timeline of the movieclip, including the <em>filters</em>.
		 */
		private function getMovieClipFramesBounds():Rectangle {
			const initialFrameIndex:int = _movieClip.currentFrame;
			
			_movieClip.gotoAndStop(1);
			var fullBounds:Rectangle = getFullBounds();
			
			for (var i:int = 2; i <= _movieClip.totalFrames; ++i) {
				_movieClip.gotoAndStop(i);
				fullBounds = fullBounds.union(getFullBounds());
			}
			
			_movieClip.gotoAndStop(initialFrameIndex);
			return fullBounds;
		}
		
		/** Determines the full bounds to the <em>current timeline-frame</em> of the display object, including the 
		 *  <em>filters</em> applied to it.
		 */
		private function getFullBounds():Rectangle
		{
			var rect:Rectangle = getBoundaries(_target, true);
			var s:Number = AtlasGenerator.scaleFactor;
			
			snapToPixelGrid(rect.width, rect.height, s);
			
			// The _scaleX & _scaleY may have been modified
			var sX:Number = _scaleX * s;
			var sY:Number = _scaleY * s;
			
			rect.x *= sX;
			rect.y *= sY;
			rect.width *= sX;
			rect.height *= sY;
			
			return rect;
		}
		
		
		/**
		 * Manipulates the <code>_scaleX</code> and/or <code>_scaleY</code> to make the
		 * object dimensions snap to the pixel grid according to the snap options and the
		 * uniform scale amount that will be applied to the object. 
		 * @param w1 The width of the object at scaleX = 1.0.
		 * @param h1 The height of the object at scaleY = 1.0;
		 * @param s The uniform scale amount that will be applied to the object.
		 * 
		 */
		private function snapToPixelGrid(w1:Number, h1:Number, s:Number):void
		{
			if (_snap2pixelGridOptions == 0)
				return;
			
			// s:      1     _scaleX * s
			//       ---- = -------------
			// w:     w1          w
			
			const WS:Number = w1 * s,
			      HS:Number = h1 * s;
			
			var w:Number = _scaleX * WS,
				h:Number = _scaleY * HS;
			
			var widthIsAlreadySnappedToPixelGrid:Boolean = w == Math.floor(w),
				heigthIsAlreadySnappedToPixelGrid:Boolean = h == Math.floor(h);
			
			if (_snap2pixelGridOptions & SNAP2PIXELGRID_PROPORTIONAL) 
			{
				// When the snap-to-pixelGrid is 'Proportional', only ONE option can be set at a
				// time; the first encountered option (i.e. the lowest-valued one) will be set,
				// discarding all the other options.
				
				// TO-DOCUMENT: When its 'proportional', eigther or both of the specified
				//              _scaleX and/or _scaleY may be overried!
				if (_snap2pixelGridOptions & SNAP2PIXELGRID_FLOOR_WIDTH) {
					if (!widthIsAlreadySnappedToPixelGrid) {
						_scaleX = _scaleY = Math.floor(w) / WS;
					}
				}
				else if (_snap2pixelGridOptions & SNAP2PIXELGRID_CEIL_WIDTH) {
					if (!widthIsAlreadySnappedToPixelGrid) {
						_scaleX = _scaleY = Math.ceil(w) / WS;
					}
				}
				else if (_snap2pixelGridOptions & SNAP2PIXELGRID_ROUND_WIDTH) {
					if (!widthIsAlreadySnappedToPixelGrid) {
						_scaleX = _scaleY = Math.round(w) / WS;
					}
				}
				else if (_snap2pixelGridOptions & SNAP2PIXELGRID_FLOOR_HEIGHT) {
					if (!heigthIsAlreadySnappedToPixelGrid) {
						_scaleY = _scaleX = Math.floor(h) / HS;
					}
				}
				else if (_snap2pixelGridOptions & SNAP2PIXELGRID_CEIL_HEIGHT) {
					if (!heigthIsAlreadySnappedToPixelGrid) {
						_scaleY = _scaleX = Math.ceil(h) / HS;
					}
				}
				else if (_snap2pixelGridOptions & SNAP2PIXELGRID_ROUND_HEIGHT) {
					if (!heigthIsAlreadySnappedToPixelGrid) {
						_scaleY = _scaleX = Math.round(h) / HS;
					}
				}
				else if (_snap2pixelGridOptions & SNAP2PIXELGRID_PROPORTIONAL_BOTH_INTEGER_PREFER_SMALLER) {
					if (! (widthIsAlreadySnappedToPixelGrid && heigthIsAlreadySnappedToPixelGrid)) {
						// TODO
					}
				}
				else if (_snap2pixelGridOptions & SNAP2PIXELGRID_PROPORTIONAL_BOTH_INTEGER_LARGER) {
					if (! (widthIsAlreadySnappedToPixelGrid && heigthIsAlreadySnappedToPixelGrid)) {
						// TODO
					}
				}
			}
			else
			{
				// When the snap-to-pixelGrid is 'Deformational', either, or both of the sides 
				// can be floored or ceiled.
				
				// Only one of the floor, ceil, or round properties can be present for the width
				if (_snap2pixelGridOptions & SNAP2PIXELGRID_FLOOR_WIDTH) {
					if (!widthIsAlreadySnappedToPixelGrid) {
						_scaleX = Math.floor(w) / WS;
					}
				}
				else if (_snap2pixelGridOptions & SNAP2PIXELGRID_CEIL_WIDTH) {
					if (!widthIsAlreadySnappedToPixelGrid) {
						_scaleX = Math.ceil(w) / WS;
					}
				}
				else if (_snap2pixelGridOptions & SNAP2PIXELGRID_ROUND_WIDTH) {
					if (!widthIsAlreadySnappedToPixelGrid) {
						_scaleX = Math.round(w) / WS;
					}
				}
				
				// Only one of the floor or ceil properties can be present for the height
				if (_snap2pixelGridOptions & SNAP2PIXELGRID_FLOOR_HEIGHT) {
					if (!heigthIsAlreadySnappedToPixelGrid) {
						_scaleY = Math.floor(h) / HS;
					}
				}
				else if (_snap2pixelGridOptions & SNAP2PIXELGRID_CEIL_HEIGHT) {
					if (!heigthIsAlreadySnappedToPixelGrid) {
						_scaleY = Math.ceil(h) / HS;
					}
				}
				else if (_snap2pixelGridOptions & SNAP2PIXELGRID_ROUND_HEIGHT) {
					if (!heigthIsAlreadySnappedToPixelGrid) {
						_scaleY = Math.round(h) / HS;
					}
				}
			}
		}
		
		internal function transformFilters(rotated:Boolean):void
		{
			transformObjectFilters(
				_scaleFilters ? scaleX : 1.0,
				_scaleFilters ? scaleY : 1.0,
				rotated ? 90 : 0
			);
		}
		
		private function transformObjectFilters(sX:Number, sY:Number, r:Number):void
		{
			function toRadian(d:Number):Number { return Math.PI * d / 180.0; }
			function toDegree(r:Number):Number { return 180.0 * r / Math.PI; }
			
			var descendants:Vector.<DisplayObjectContainer> = _traversed.nodes as Vector.<DisplayObjectContainer>;
			var descendatnsCount:uint = descendants.length;
			
			for (var i:uint = 0; i<descendatnsCount; ++i)
			{
				var descendant:DisplayObjectContainer = descendants[i];
				
				var filtersCount:uint = descendant.filters.length;
				
				var cpyFilters:Array = [];
				for (var j:uint = 0; j<filtersCount; ++j)
				{
					var filter:BitmapFilter = descendant.filters[j];
					
					if (filter.hasOwnProperty("blurX"))
					{
						filter["blurX"] = filter["blurX"] * sX;
					}
					
					if (filter.hasOwnProperty("blurY"))
					{
						filter["blurY"] = filter["blurY"] * sY;
					}
					
					if (filter.hasOwnProperty("distance") && filter.hasOwnProperty("angle"))
					{
						var d:Number = filter["distance"];
						var angle:Number = toRadian(filter["angle"]);
						var w:Number = (d * Math.sin(angle)) * sX;
						var h:Number = (d * Math.cos(angle)) * sY;
						filter["distance"] = Math.sqrt(w*w + h*h);
						filter["angle"] = toDegree(w == 0 ? angle : Math.atan(h/w)) + r;
					}
					
					cpyFilters.push(filter);
				}
				
				// update filters
				descendant.filters = cpyFilters;
			}
		}
		
		private function getBareBounds():Rectangle
		{
			var rect:Rectangle = getBoundaries(_target, false);
			var s:Number = AtlasGenerator.scaleFactor;
			
			snapToPixelGrid(rect.width, rect.height, s);
			
			// The _scaleX & _scaleY may have been modified
			var sX:Number = _scaleX * s;
			var sY:Number = _scaleY * s;
			
			rect.x *= sX;
			rect.y *= sY;
			rect.width *= sX;
			rect.height *= sY;
			
			return rect;
		}
		
		
		private function getBoundaries(obj:DisplayObjectContainer, filters:Boolean = true):Rectangle
		{
			var rect:Rectangle = obj.getBounds(null);
			
			if (filters)
			{
				var nodes:Vector.<DisplayObjectContainer> = _traversed.nodes;
				var depth:Vector.<uint> = _traversed.depth;
				
				var rectsStack:Vector.<Rectangle> = new Vector.<Rectangle>();
				rectsStack.push(boundariesWithFilter(nodes[0], obj, null));
				
				function unionWithHeadRect(rect:Rectangle):void
				{
					var len:uint = rectsStack.length;
					if (len == 0)
					{
						rectsStack.push(rect);
						return;
					}
					var l:uint = len - 1;
					rectsStack[l] = rectsStack[l].union(rect);
				}
				
				var allDescendantsCount:uint = nodes.length;
				for (var i:uint = 1; i<allDescendantsCount; ++i)
				{
					var prevDepth:uint = depth[i-1], currentDepth:uint = depth[i];
					if (prevDepth == currentDepth)
					{
						unionWithHeadRect(boundariesWithFilter(nodes[i], obj, null));
					}
					else
					{
						if (currentDepth + 1 == prevDepth)
						{
							unionWithHeadRect( boundariesWithFilter(nodes[i], obj, rectsStack.pop()) );
						}
						else
						{
							rectsStack.push( boundariesWithFilter(nodes[i], obj, null) );
						}
					}
				}
				
				return rectsStack[0];
			}
			
			return rect;
		}
		
		private function boundariesWithFilter(obj:DisplayObjectContainer, targetCoordinateSpace:DisplayObject, initialBounds:Rectangle = null):Rectangle
		{
			var bounds:Rectangle = obj.getBounds(targetCoordinateSpace);
			
			if (initialBounds)
				bounds = bounds.union(initialBounds);
			
			var filtersCount:uint = obj.filters.length, tmpFilterRect:Rectangle;
			for (var i:uint = 0; i<filtersCount; ++i)
			{
				var bitmapData:BitmapData = new BitmapData(bounds.width, bounds.height, false, 0);
				
				tmpFilterRect = bitmapData.generateFilterRect(
					new Rectangle(0, 0, bounds.width, bounds.height),
					obj.filters[i]
				);
				tmpFilterRect.offset(bounds.left, bounds.top);
				
				bounds = bounds.union(tmpFilterRect);
			}
			
			return bounds;
		}
		
		/**
		 * Iteratively traverses throughout the display object heirarchy tree whose root is provided through the specified node 
		 * parameter object.
		 * The traverse is performed using a <em>Depth First</em> (DF) pattern of post order (the traverse starts from a deep node on 
		 * the leftmost sub-tree, makes its way up to the root node, visiting all the nodes exactly once.)
		 * @return Returns an object with two fields:
		 *  <ul><li>
		 *      <code>nodes</code>; a list of type: <code>Vector.<DisplayObjectContainer></code><br>
		 *      The list of traveresed nodes using a <em>Depth First</em> (DF) pattern of post order
		 *      (The deepest node (DF) in the leftmost sub-tree (post order) first.)
		 *    </li><li>
		 *      <code>depth</code>; a list of type: <code>Vector.<uint></code><br>
		 *    </li><li>
		 *      The corresponding depth to each node in the tree. The values of the list are in a one-to-one correspondence
		 *      together with the values in the list of <code>nodes</code> that determine how deep the nodes are placed in the heirarchy
		 *      tree.<br>
		 *      A value of zero (0) indicates the root node which is the topmost node; a value of one (1) indicates the direct
		 *      children of the root node; a value of two (2) indicates the direct children of the ancestor node that has a depth value 
		 *      of one; and so forth.
		 *  </li></ul>
		 *  Consider the following tree:<br>
		 <pre>
		 0                          A
		              ┌─────────────┼─────────────┐
		 1            B             C             D
		          ┌───┼───┐      ┌──┴──┐      ┌───┼───┐
		 2        E   F   G      H     I      J   K   L
		       ┌──┴──┐    |            |          |
		 3     M     N    O            P          Q
		               ┌──┴──┐                ┌───┼───┐
		 4             S     R                T   U   V
		                                   ┌──┴──┐
		 5                                 W     X
		 </pre>
		 *  The output will be an object that has the following values:<br>
		 *  <code> nodes:  M, N, E, F, S, R, O, G, B, H, P, I, C, J, W, X, T, U, V, Q, K, L, D, A</code><br>
		 *  <code> depth:  3, 3, 2, 2, 4, 4, 3, 2, 1, 2, 3, 2, 1, 2, 5, 5, 4, 4, 4, 3, 2, 2, 1, 0</code>
		 *  <hr> Development: Ehsan Marufi Azar, 20 Nov. 2017 (c)
		 */
		private function traverseNaryTreePostOrder(node:DisplayObjectContainer):Object
		{
			if (node == null)
				return null;
			
			// A list to hold the output nodes
			var arrNodes:Vector.<DisplayObjectContainer> = new Vector.<DisplayObjectContainer>();
			
			// A list to hold the output depth
			var arrDepth:Vector.<uint> = new Vector.<uint>();
			
			// Internally used stack objects
			var depthStack:Vector.<uint> = new Vector.<uint>();
			var unprocessedStack:Vector.<DisplayObjectContainer> = new Vector.<DisplayObjectContainer>();
			
			// Initialize the stacks with the root node
			unprocessedStack.push(node);
			depthStack.push(1);
			
			// Declare all the variables outside of the `while` loop for performance considarations
			var i:uint, childrenCount:uint, displayObject:DisplayObject, len:uint, l:uint, c:uint;
			
			while (unprocessedStack.length > 0)
			{
				node = unprocessedStack.pop();
				
				len = depthStack.length - 1;
				
				// Every time a node is popped off the stack, the siblings count in the topmost entry of the depth stack should be
				// decreased accordingly.
				--depthStack[len];
				
				// Inset the popped node at the begining of the output list
				arrNodes.unshift(node);
				
				// Insert the corresponding depth of the popped node
				arrDepth.unshift(len);
				
				// The valid children of the popped (the containers) will be pushed into `unprocessedStack`.
				// The count of the valid children (the containers) will be tracked using variable of `c`.
				childrenCount = node.numChildren;
				c = 0;
				
				for (i = 0; i<childrenCount; ++i)
				{
					displayObject = node.getChildAt(i);
					if (displayObject is DisplayObjectContainer)
					{
						// All of the children will be pushed into the stack to be popped off it later, one at a time
						unprocessedStack.push(displayObject);
						c++; 
					}
				}
				
				
				if (c > 0)
				{
					// If there were some valid children (some deeper containers), then push a deeper depth level!
					// (Push a new entry with a sum of `c` siblings into the depth stack. The count of the siblings will 
					//  be decreased every time a node is popped off the stack, i.e. when the node is processed.)
					depthStack.push(c);
				}
				else
				{
					// The popped node doesn't have any valid children (no deeper containers).
					// So, check if all the siblings in the container have been processed entirely:
					if (depthStack[len] == 0)
					{
						// Repeatedly ascend the depth level up, until a depth level is reached whose sibling objects are 
						// waiting to be processed.
						do
						{
							depthStack.pop();
							//trace("poped, new depth stack: "+depthStack); // TO-REMOVE
							l = depthStack.length;
						} while (l > 0 && depthStack[l-1] == 0);
					}
				}
			}
			
			return {nodes: arrNodes, depth: arrDepth};
		}
	}
}