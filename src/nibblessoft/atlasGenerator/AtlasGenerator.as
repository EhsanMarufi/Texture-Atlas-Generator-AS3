// Atlas Generator
// Ehsan Marufi (c) December 2017

package nibblessoft.atlasGenerator
{
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.display.StageQuality;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.geom.Matrix;
	
	import nibblessoft.rbp.MaxRectsBinPack;
	import nibblessoft.rbp.Rect;

	[Event(name="progress", type="nibblessoft.atlasGenerator.AtlasGeneratorEvent")]
	[Event(name="complete", type="nibblessoft.atlasGenerator.AtlasGeneratorEvent")]
	
	/**
	 * Generates atlas dynamically at runtime.
	 * // TODO: ELABORATE ON DOCUMENTATIONS! 
	 */
	public class AtlasGenerator extends EventDispatcher
	{
		public static const PROGRESS:String = "progress";
		
		/** The maximum allowed <code>draw()</code> operations per each frame.*/
		public static var drawLimit:uint = 5;//uint.MAX_VALUE;
		
		private var _spriteSheetWidth:uint;
		private var _spriteSheetHeight:uint;
		private var _arrSpriteSheets:Vector.<BitmapData>;
		private var _arrXMLs:Vector.<XML>;
		private var _arrMaxRectBinPacks:Vector.<MaxRectsBinPack>;
		
		private var _totalAtlasesCount:uint = 0;
		
		private var _toDrawList:Array;
		private var _currentItem:AtlasItem;

		private var _stage:Stage;
		
		private static var _scaleFactor:Number;
		public static function get scaleFactor():Number { return _scaleFactor; }
		
		private var _matrix1:Matrix, _matrix2:Matrix;
		
		private var _busyDrawing:Boolean = false;
		
		private var _drawQuality:String;
		
		private var _subTexturesGap:uint;
		public function getSubTexturesGap():uint { return _subTexturesGap; }
		
		private var _debugging:Boolean;
		public function debugging():Boolean { return _debugging; }
		
		private var _BBRectSprite:Sprite;
		private var _matBB:Matrix;
		
		private var _totalToDrawItems:uint;
		private var _totalFramesInserted:uint;
		private var _progress:Number = 0.0;
		
		public function get XMLs():Vector.<XML> { return _arrXMLs; }
		public function get spriteSheets():Vector.<BitmapData> { return _arrSpriteSheets; }
		public function get maxRectBinPacks():Vector.<MaxRectsBinPack> { return _arrMaxRectBinPacks; }
		public function get progress():Number { return _progress; }
		public function get totalToDrawItems():uint { return _totalToDrawItems; }
		public function get totalFramesInserted():uint { return _totalFramesInserted; }
		
		public function AtlasGenerator(
				spriteSheetWidth:uint,
				spriteSheetHeight:uint,
				drawList:Array,
				drawQuality:String = StageQuality.BEST,
				scaleFactor:Number = 1.0,
				scaleFilters:Boolean = true,
				subTexturesGap:uint = 4,
				debugging:Boolean = true
		) {
			_drawQuality = drawQuality;
			_subTexturesGap = subTexturesGap;
			
			_spriteSheetWidth = spriteSheetWidth;
			_spriteSheetHeight = spriteSheetHeight;

			_arrSpriteSheets = new Vector.<BitmapData>();
			_arrXMLs = new Vector.<XML>();
			_arrMaxRectBinPacks = new Vector.<MaxRectsBinPack>();

			
			addAtlas();
			
			_scaleFactor = scaleFactor;
			
			_debugging = debugging;
			if (_debugging) {
				_BBRectSprite = new Sprite();
				_matBB = new Matrix();
			}
			
			_toDrawList = drawList.concat();
			_totalToDrawItems = _toDrawList.length;
			_totalFramesInserted = 0;
			
			_matrix1 = new Matrix(1, 0,  0, 1, 0, 0);
			_matrix2 = new Matrix(0, 1, -1, 0, 0, 0); // rotated 90 degrees
			
			trace("Items count to be inserted in TextureAtlas: "+_toDrawList.length);
		}
		
		private function addAtlas():void 
		{
			_arrSpriteSheets.push(new BitmapData(_spriteSheetWidth, _spriteSheetHeight, true, 0));
			
			var xml:XML = new XML(<TextureAtlas></TextureAtlas>);
			xml.@imagePath = "atlas"+_arrSpriteSheets.length+".png";
			xml.@subTexturesGap = _subTexturesGap;
			_arrXMLs.push(xml);
			
			_arrMaxRectBinPacks.push(new MaxRectsBinPack(_spriteSheetWidth, _spriteSheetHeight));
			
			_totalAtlasesCount++;
		}
		
		public function beginBatchDraw(stage:Stage):void
		{
			_stage = stage;
			_stage.addEventListener(Event.EXIT_FRAME, onExitFrame);
			
			// TODO: REMOVE THE FOLLOWING LINE
			//_stage.addChild(new Bitmap(_spriteSheet));
		}
		
		private function onExitFrame(e:Event):void 
		{
			if (!_busyDrawing)
			{
				draw();
				_progress = 1.0 - (_toDrawList.length / _totalToDrawItems);
				dispatchEvent(new AtlasGeneratorEvent(PROGRESS, this));
			}
		}
		
		private function draw():void
		{
			_busyDrawing = true;
			for (var i:uint = 0; i < drawLimit; ++i)
			{
				prepareNextFrame();
				
				// check if there's no more objects to draw
				if (_currentItem == null)
				{
					_stage.removeEventListener(Event.EXIT_FRAME, onExitFrame);
					
					// dispatch the complete event
					dispatchEvent(new AtlasGeneratorEvent(Event.COMPLETE, this));
					
					break;
				}
				else
				{
					// An object is prepared to get drawn
					drawOneFrame();
				}
			}
			
			_busyDrawing = false;
		}
		
		private function drawOneFrame():void 
		{
			var gap:uint = _subTexturesGap;
			var w:int = Math.round(_currentItem.fullBoundingBox.width),
				h:int = Math.round(_currentItem.fullBoundingBox.height);
			
			// The Full-Width (FW) & Full-Height (FH)
			const FW:uint = w + gap, FH:uint = h + gap;
			
			if ((FW > _spriteSheetWidth && FW > _spriteSheetHeight) ||
				(FH > _spriteSheetHeight && FH > _spriteSheetWidth))
			{
				// The required rectangular space is bigger than the specified size of spreadsheets 
				// and thus will not be fitted inside any one of them!
				trace("The input rectangle of (w: "+FW+", h:"+FH+") cannot be fitted inside any " +
					"rectangular bin of (w: "+_spriteSheetWidth+", h: "+_spriteSheetHeight+")");
				return;
			}
			
			var insertedRect:Rect, i:int;
			var spriteSheet:BitmapData,
				xml:XML;
			
			// Iterate through all the available atlases to find the first atlas that has the required
			// rectangular space available for the display object to be drawn on.
			for (i = 0; i < _totalAtlasesCount; ++i)
			{
				insertedRect = _arrMaxRectBinPacks[i].insert(
					FW,
					FH,
					MaxRectsBinPack.FRCH_RectBestShortSideFit
				);
				
				// The first non-degenerate rectangle indicates the insertion was successful at finding
				// an appropriate location for the required space.
				if (insertedRect.height > 0)
					break;
			}
			
			// If the required space has not been found on any of the available spreadsheets, then
			// add an extra atlas and retry brand new!
			if (i == _totalAtlasesCount)
			{
				addAtlas();
				drawOneFrame();
				return;
			}
			
			spriteSheet = _arrSpriteSheets[i];
			xml = _arrXMLs[i];

			
			insertedRect.width -= gap;
			insertedRect.height -= gap;
			
			// Check if the inserted rect is rotated
			var isRotated:Boolean = w != h 
				&& insertedRect.width  == h 
				&& insertedRect.height == w;
			
			var matrix:Matrix = getMatrix(
				isRotated,
				//insertedRect.x + (isRotated ? _currentItem.bareBoundingBox.y+_currentItem.bareBoundingBox.height+_currentItem.filtersExtensionLeft : -_currentItem.bareBoundingBox.x+_currentItem.filtersExtensionLeft),
				//insertedRect.y - (isRotated ? _currentItem.bareBoundingBox.x-_currentItem.filtersExtensionTop :  _currentItem.bareBoundingBox.y-_currentItem.filtersExtensionTop)
				//insertedRect.x + (isRotated ? _currentItem.bareBoundingBox.height-_currentItem.bareBoundingBox.top+_currentItem.filtersExtensionLeft : -_currentItem.bareBoundingBox.x+_currentItem.filtersExtensionLeft),
				//insertedRect.y - (isRotated ? _currentItem.bareBoundingBox.x-_currentItem.filtersExtensionTop :  _currentItem.bareBoundingBox.y-_currentItem.filtersExtensionTop)
				insertedRect.x + (isRotated ? _currentItem.fullBoundingBox.bottom : -_currentItem.fullBoundingBox.left),
				insertedRect.y - (isRotated ? _currentItem.fullBoundingBox.left : _currentItem.fullBoundingBox.top)
			);
			
			_currentItem.transformFilters(isRotated);
			
			if (_debugging) {
				_BBRectSprite.graphics.clear();
				_BBRectSprite.graphics.beginFill(isRotated ? 0xFFFF00 : 0x00FF00, 0.65);
				_BBRectSprite.graphics.drawRect(0, 0, insertedRect.width, insertedRect.height);
				_BBRectSprite.graphics.endFill();
				_matBB.tx = insertedRect.x;
				_matBB.ty = insertedRect.y;
				spriteSheet.draw(_BBRectSprite, _matBB);
			}
			
			// The main draw operation
			spriteSheet.drawWithQuality(
				_currentItem.target,
				matrix,
				null, // colorTransform
				null, // blendMode
				null, // clipRect
				false, // smoothing
				_drawQuality
			);
			
			var subTexXML:XML = new XML(<SubTexture />);
			subTexXML.@name = _currentItem.currentFrameName;
			subTexXML.@x = insertedRect.x;
			subTexXML.@y = insertedRect.y;
			subTexXML.@width = insertedRect.width;
			subTexXML.@height = insertedRect.height;
			subTexXML.@rotated = isRotated ? "true" : "false";
			subTexXML.@frameX = _currentItem.fullFramesBoundingBox.x - _currentItem.fullBoundingBox.x;
			subTexXML.@frameY = _currentItem.fullFramesBoundingBox.y - _currentItem.fullBoundingBox.y;
			subTexXML.@frameWidth = _currentItem.fullFramesBoundingBox.width;
			subTexXML.@frameHeight = _currentItem.fullFramesBoundingBox.height;
			subTexXML.@framePivotX = _currentItem.fullFramesBoundingBox.x;
			subTexXML.@framePivotY = _currentItem.fullFramesBoundingBox.y;
			
			xml.appendChild(subTexXML);
		}
		
		private function getMatrix(isRotated90Degrees:Boolean, tx:int, ty:int):Matrix {
			var matrix:Matrix;
			if (isRotated90Degrees) {
				matrix = _matrix2;
				matrix.b = _currentItem.scaleX * _scaleFactor;
				matrix.c = -_currentItem.scaleY * _scaleFactor;
			} else {
				matrix = _matrix1;
				matrix.a = _currentItem.scaleX * _scaleFactor;
				matrix.d = _currentItem.scaleY * _scaleFactor;
			}
			matrix.tx = tx;
			matrix.ty = ty;
			return matrix;
		}
		
		private function prepareNextFrame():void 
		{
			if (_currentItem && _currentItem.prepareNextFrame()) {
				_totalFramesInserted++;
			} else {
				// Take out another object from the list
				_currentItem = _toDrawList.pop();
				if (_currentItem != null) {
					_currentItem.prepareFirstFrame();
					_totalFramesInserted++;
				}
			}
		}
	}
}