// Atlas Generator
// Ehsan Marufi (c) December 2017

package nibblessoft.atlasGenerator
{
	import flash.events.Event;
	
	public class AtlasGeneratorEvent extends Event
	{
		private	var _dynamicAtlasGenerator:AtlasGenerator;
		public function AtlasGeneratorEvent(type:String, dynamicAtlasGenerator:AtlasGenerator, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
			_dynamicAtlasGenerator = dynamicAtlasGenerator;
		}
		
		public function get atlasGeneratorObj():AtlasGenerator { return _dynamicAtlasGenerator; }
	}
}