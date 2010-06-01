package
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.*;
	import flash.filters.DropShadowFilter;
	import flash.geom.ColorTransform;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.text.AntiAliasType;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.ui.Mouse;
	
	public class TrashPaint extends Sprite
	{
		//Paper vars
		protected var _paper:Bitmap;
		protected var _pColor:uint;
		protected var _w:uint;
		protected var _h:uint;
		protected var _help:TextField;
		protected var _focus:TextField;
		
		//Overlay vars
		protected var _overlay:Bitmap;
		protected var _oCT:ColorTransform;
		protected var _oRect:Rectangle;
		
		//Brush vars
		protected var _brush:Bitmap;
		protected var _bMtx:Matrix;
		protected var _bOld:Point;
		protected var _bLerp:Boolean;
		protected var _painting:Boolean;
		protected var _bCurSize1:uint;
		protected var _bCurSize2:uint;
		protected var _bToggle:Boolean;
		protected var _bSizes:Array;
		protected var _bColor:uint;
		protected var _bHelper:Sprite;
		protected var _bReticle:Sprite;
		
		//Eyedropper vars
		protected var _eyedropMode:Boolean;
		protected var _kCtrl:Boolean;
		protected var _kAlt:Boolean;
		protected var _kShift:Boolean;
		protected var _eReticle:Sprite;
		protected var _ePreview:Sprite;
		
		//Color tool vars
		protected var _colorTool:Sprite;
		protected var _barHue:Sprite;
		protected var _barSat:Sprite;
		protected var _barBrt:Sprite;
		protected var _colorNew:Bitmap;
		protected var _colorOld:Bitmap;
		protected var _cr:Rectangle;
		protected var _colorTarget:Sprite;
		protected var _valHue:Number;
		protected var _valSat:Number;
		protected var _valBrt:Number;
		protected var _sliderHue:Sprite;
		protected var _sliderSat:Sprite;
		protected var _sliderBrt:Sprite;

		public function TrashPaint()
		{
			addEventListener(Event.ENTER_FRAME, create);
		}
		
		/**
		 * Used to instantiate the guts of the app once we have a valid pointer to the stage & root
		 */
		protected function create(event:Event):void
		{
			if(root == null)
				return;
			removeEventListener(Event.ENTER_FRAME, create);
			
			//Set up the view window and double buffering
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
			stage.frameRate = 60;
			
			//All-purpose drop shadow
			var dropShadow:DropShadowFilter = new DropShadowFilter();
			dropShadow.color = 0x000000;
			dropShadow.blurX = 2;
			dropShadow.blurY = 2;
			dropShadow.angle = 0;
			dropShadow.distance = 0;
			dropShadow.strength = 2;
			dropShadow.quality = 5;
			var filtersArray:Array = new Array(dropShadow);
			
			//Focus helper
			_focus = new TextField();
			_focus.x = 4;
			_focus.alpha = 0.65;
			_focus.width = 200;
			_focus.height = 20;
			_focus.multiline = true;
			_focus.wordWrap = true;
			_focus.selectable = false;
			_focus.defaultTextFormat = new TextFormat("Verdana",11,0xffffff,true,null,null,null,null,null,null,null,null,4);
			_focus.text = "Click to restore focus.";
			_focus.filters = filtersArray;
			
			//Initialize paper-related stuff
			_w = 0;
			_h = 0;
			_paper = null;
			_pColor = 0xffa39b9d;
			_oRect = new Rectangle();
			_oCT = new ColorTransform();
			
			//Create the color tool
			var baseline:int = 0;
			var left:uint = 155;
			var barWidth:uint = 400;
			var barHeight:uint = 34;
			var spacing:uint = barHeight + 16;
			var colorBox:uint = 134;
			_colorTool = new Sprite();
			
			//Brightness bar
			_barBrt = new Sprite();
			_barBrt.x = left;
			_barBrt.y = -spacing;
			_colorTool.addChild(_barBrt);
			_sliderBrt = new Sprite();
			_sliderBrt.graphics.lineStyle(1,0xffffff,1);
			_sliderBrt.graphics.drawRoundRect(-2,-2,5,barHeight+4,4,4);
			_barBrt.addChild(_sliderBrt);
			
			//Saturation bar
			_barSat = new Sprite();
			_barSat.x = left;
			_barSat.y = _barBrt.y - spacing;
			_colorTool.addChild(_barSat);
			_sliderSat = new Sprite();
			_sliderSat.graphics.lineStyle(1,0xffffff,1);
			_sliderSat.graphics.drawRoundRect(-2,-2,5,barHeight+4,4,4);
			_barSat.addChild(_sliderSat);
			
			//Hue bar
			_barHue = new Sprite();
			_barHue.x = left;
			_barHue.y = _barSat.y - spacing;
			_barHue.graphics.beginFill(0xFF0000);
			_barHue.graphics.drawRect(0,0,barWidth,barHeight);
			_barHue.graphics.endFill();

			//Set up the hue bars gradient right here (since it's static)
			var hChunk:uint = barWidth/6;
			var hFillType:String = "linear";
			var hColors:Array = [0xFF0000, 0xFFFF00, 0x00FF00, 0x00FFFF, 0x0000FF, 0xFF00FF];
			var hAlphas:Array = [1, 1];
			var hRatios:Array = [0, 255];
			var hMatrix:Matrix = new Matrix();
			for(var i:uint = 0; i < 6; i++)
			{
				hMatrix.createGradientBox(hChunk,barHeight,0,hChunk*i,0);
				_barHue.graphics.beginGradientFill("linear", [hColors[i],hColors[(i+1)%6]], hAlphas, hRatios, hMatrix);
				_barHue.graphics.drawRect(hChunk*i,0,hChunk,barHeight);
				_barHue.graphics.endFill();
			}
			
			//Finish hue bar setup
			_colorTool.addChild(_barHue);
			_sliderHue = new Sprite();
			_sliderHue.graphics.lineStyle(1,0xffffff,1);
			_sliderHue.graphics.drawRoundRect(-2,-2,5,barHeight+4,4,4);
			_barHue.addChild(_sliderHue);
			
			//Color boxes
			_cr = new Rectangle();
			_cr.width = colorBox;
			_cr.height = colorBox/2;
			_colorNew = new Bitmap(new BitmapData(_cr.width,_cr.height,false));
			_colorNew.y = -150;
			_colorTool.addChild(_colorNew);
			_colorOld = new Bitmap(new BitmapData(_cr.width,_cr.height,false));
			_colorOld.y = -83;
			_colorTool.addChild(_colorOld);
			_colorTool.filters = filtersArray;
			_colorTool.visible = false;
			
			//Set up the paper and color tool positions and sizes
			onResize();
			addChild(_colorTool);
			
			//Brush initialization stuff
			_bColor = 0xff5a5c64;
			storeColor();
			_bMtx = new Matrix();
			_bOld = null;
			_bLerp = true;
			_painting = false;
			_bHelper = new Sprite();
			
			//Set up the drawing reticle/guide
			_bReticle = new Sprite();
			_bReticle.filters = filtersArray;
			
			//Finish brush initialization
			_bSizes = new Array( 1, 2, 3, 5, 7, 9, 15, 21, 29, 39, 49, 59, 79, 99, 119, 139, 159, 179 );
			_bCurSize1 = 7;
			_bCurSize2 = 1
			_bToggle = false;
			resizeBrush();
			addChild(_bReticle);
			
			//Eye dropper controls
			_eyedropMode = false;
			_kAlt = false;
			_kCtrl = false;
			_kShift = false;
			
			//Eye dropper pixel previewer
			_ePreview = new Sprite();
			_ePreview.filters = filtersArray;
			addChild(_ePreview);
			
			//Eye dropper reticle/guide
			_eReticle = new Sprite();
			_eReticle.graphics.clear();
			_eReticle.graphics.lineStyle(1,0xffffff,0.65);
			_eReticle.graphics.drawCircle(0.5,0.5,7);
			_eReticle.graphics.drawRect(-1,-1,3,3);
			_eReticle.filters = filtersArray;
			addChild(_eReticle);
			
			//Text helpers
			_help = new TextField();
			_help.x = _help.y = 4;
			_help.alpha = 0.5;
			_help.width = 200;
			_help.height = 150;
			_help.multiline = true;
			_help.wordWrap = true;
			_help.selectable = false;
			_help.defaultTextFormat = new TextFormat("Verdana",11,0xffffff,true,null,null,null,null,null,null,null,null,4);
			_help.text = "";
			_help.appendText("H: Toggle Help\n");
			_help.appendText("B: Brush Toggle\n");
			_help.appendText("Space: Color Tool\n");
			_help.appendText("-/+/[]: Brush Size\n");
			_help.appendText("F/M: Flip Painting\n");
			_help.appendText("Numbers: Brush Opacity\n");
			_help.appendText("Ctrl/Alt/Shift: Grab Color\n");
			_help.filters = filtersArray;
			addChild(_help);
			addChild(_focus);

			//Add basic input even listeners
			stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
			stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
			stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
			stage.addEventListener(MouseEvent.MOUSE_OUT, onMouseOut);
			stage.addEventListener(MouseEvent.MOUSE_OVER, onMouseOver);
			stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
			stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
			stage.addEventListener(Event.DEACTIVATE, onFocusLost);
			stage.addEventListener(Event.ACTIVATE, onFocus);
			stage.addEventListener(Event.RESIZE, onResize);
			
			//That's it!  All set
			addEventListener(Event.ENTER_FRAME, update);
		}
		
		/**
		 * This is the main app loop.  It controls all the updating and rendering.
		 */
		protected function update(event:Event):void
		{
			if(_eyedropMode || _colorTool.visible)
			{
				_overlay.visible = false;
				_brush.visible = false;
				_bReticle.visible = false;
				_eReticle.visible = true;
				_ePreview.visible = _painting && !_colorTool.visible;
			}
			else
			{
				_ePreview.visible = false;
				_eReticle.visible = false;
				_bReticle.visible = true;
				_overlay.visible = _painting;
				_brush.visible = !_painting;
			}
			
			if(_colorTool.visible)
			{
				_sliderHue.x = (_valHue/360)*_barHue.width;
				if(_sliderHue.x > 400)
					_sliderHue.x = 400;
				_sliderSat.x = (_valSat)*_barSat.width;
				if(_sliderSat.x > 400)
					_sliderSat.x = 400;
				_sliderBrt.x = (_valBrt)*_barBrt.width;
				if(_sliderBrt.x > 400)
					_sliderBrt.x = 400;
			}
		}
		
		/**
		 * Creates and resizes the paper.
		 */
		protected function resizePaper():void
		{
			var oldPaper:Bitmap = _paper;
			_paper = new Bitmap(new BitmapData(_w,_h,true,_pColor));
			addChild(_paper);
			if(oldPaper != null)
			{
				_paper.bitmapData.draw(oldPaper);
				swapChildren(oldPaper,_paper);
				removeChild(oldPaper);
			}
			
			var oldOverlay:Bitmap = _overlay;
			_overlay = new Bitmap(new BitmapData(_w,_h,true,0));
			addChild(_overlay);
			if(oldOverlay != null)
			{
				swapChildren(oldOverlay,_overlay);
				removeChild(oldOverlay);
			}
			_oRect.width = _w;
			_oRect.height = _h;
		}
		
		/**
		 * Creates and resizes the brush.
		 */
		protected function resizeBrush():void
		{
			var oldBrush:Bitmap = _brush;
			createBrush();
			addChild(_brush);
			if(oldBrush != null)
			{
				swapChildren(oldBrush,_brush);
				removeChild(oldBrush);
			}
		}
		
		/**
		 * Actually creates the new brush.
		 */
		protected function createBrush():void
		{
			var s:uint = _bSizes[_bToggle?_bCurSize2:_bCurSize1];
			var s2:uint = s/2;
			
			//Create brush graphic
			_brush = new Bitmap(new BitmapData(s,s,true,0));
			_bHelper.graphics.clear();
			_bHelper.graphics.beginFill(_bColor);
			_bHelper.graphics.drawRoundRect(0,0,s,s,s2,s2);
			_bHelper.graphics.endFill();
			_brush.bitmapData.draw(_bHelper);
			
			//Create brush guide graphic
			_bReticle.graphics.clear();
			_bReticle.graphics.lineStyle(1,0xffffff,0.65);
			_bReticle.graphics.drawRoundRect(-1,-1,s+2,s+2,s2+2,s2+2);
			
			//Misc stuff
			_overlay.alpha = _oCT.alphaMultiplier;
			_brush.alpha = _oCT.alphaMultiplier;
			onMouseMove();
		}
		
		/**
		 * Stores the current color as a hue/sat/brt triad.
		 */
		protected function storeColor():void
		{
			var red:Number = Number((_bColor >> 16) & 0xFF) / 255;
			var green:Number = Number((_bColor >> 8) & 0xFF) / 255;
			var blue:Number = Number((_bColor) & 0xFF) / 255;
			
			var m:Number = (red>green)?red:green;
			var dmax:Number = (m>blue)?m:blue;
			m = (red>green)?green:red;
			var dmin:Number = (m>blue)?blue:m;
			var range:Number = dmax - dmin;
			
			_valBrt = dmax;
			_valSat = 0;
			_valHue = 0;
			
			if(dmax != 0)
				_valSat = range / dmax;
			if(_valSat != 0) 
			{
				if (red == dmax)
					_valHue = (green - blue) / range;
				else if (green == dmax)
					_valHue = 2 + (blue - red) / range;
				else if (blue == dmax)
					_valHue = 4 + (red - green) / range;
				_valHue *= 60;
				if(_valHue < 0)
					_valHue += 360;
			}
			updateColorBox();
		}
		
		/**
		 * Generate a new brush color based on the contents of hue/sat/brt triad.
		 */
		protected function HSBtoUint(Hue:Number,Sat:Number,Brt:Number):uint
		{
			var red:Number;
			var green:Number;
			var blue:Number;
			if(Sat == 0.0)
			{
				red   = Brt;
				green = Brt;        
				blue  = Brt;
			}       
			else
			{
				if(Hue == 360)
					Hue = 0;
				var slice:int = Hue/60;
				var hf:Number = Hue/60 - slice;
				var aa:Number = Brt*(1 - Sat);
				var bb:Number = Brt*(1 - Sat*hf);
				var cc:Number = Brt*(1 - Sat*(1.0 - hf));
				switch (slice)
				{
					case 0: red = Brt; green = cc;   blue = aa;  break;
					case 1: red = bb;  green = Brt;  blue = aa;  break;
					case 2: red = aa;  green = Brt;  blue = cc;  break;
					case 3: red = aa;  green = bb;   blue = Brt; break;
					case 4: red = cc;  green = aa;   blue = Brt; break;
					case 5: red = Brt; green = aa;   blue = bb;  break;
					default: red = 0;  green = 0;    blue = 0;   break;
				}
			}
			
			return (uint(red*255) << 16 | uint(green*255) << 8 | uint(blue*255));
		}
		
		/**
		 * Updates the contents of the 'new color' box in the color tool.
		 */
		protected function updateColorBox():void
		{
			_bColor = HSBtoUint(_valHue,_valSat,_valBrt);
			
			if(!_colorTool.visible)
				return;
			_colorNew.bitmapData.fillRect(_cr,_bColor);

			//Calculate and set the gradient for the saturation bar
			var hFillType:String = "linear";
			var hColors:Array = [HSBtoUint(_valHue,0,_valBrt),HSBtoUint(_valHue,1,_valBrt)];
			var hAlphas:Array = [1, 1];
			var hRatios:Array = [0, 255];
			var hMatrix:Matrix = new Matrix();
			hMatrix.createGradientBox(400,34);
			_barSat.graphics.clear();
			_barSat.graphics.beginGradientFill("linear", hColors, hAlphas, hRatios, hMatrix);
			_barSat.graphics.drawRect(0,0,400,34);
			_barSat.graphics.endFill();
			
			//Calculate and set the gradient for the brightness bar
			hFillType = "linear";
			hColors = [HSBtoUint(_valHue,_valSat,0),HSBtoUint(_valHue,_valSat,1)];
			hAlphas = [1, 1];
			hRatios = [0, 255];
			hMatrix = new Matrix();
			hMatrix.createGradientBox(400,34);
			_barBrt.graphics.clear();
			_barBrt.graphics.beginGradientFill("linear", hColors, hAlphas, hRatios, hMatrix);
			_barBrt.graphics.drawRect(0,0,400,34);
			_barBrt.graphics.endFill();
		}
		
		/**
		 * Takes the current paint input and applies it to the paper.
		 */
		protected function applyOverlay():void
		{
			_painting = false;
			_paper.bitmapData.draw(_overlay.bitmapData, null, _oCT);
			_overlay.bitmapData.fillRect(_oRect,0);
		}
		
		//*** EVENT HANDLERS ***//

		/**
		 * Internal event handler for input and focus.
		 */
		protected function onMouseMove(event:MouseEvent=null):void
		{
			if((event != null) && event.buttonDown)
				_painting = true;
			Mouse.hide();
			
			if(_eyedropMode || _colorTool.visible)
			{
				//Eye dropper behavior
				_ePreview.x = _eReticle.x = mouseX;
				_ePreview.y = _eReticle.y = mouseY;
				if(_painting)
				{
					if(_colorTool.visible && (_colorTarget == null))
					{
						if(_barHue.hitTestPoint(mouseX,mouseY))
							_colorTarget = _barHue;
						else if(_barSat.hitTestPoint(mouseX,mouseY))
							_colorTarget = _barSat;
						else if(_barBrt.hitTestPoint(mouseX,mouseY))
							_colorTarget = _barBrt;
					}
					
					if(_colorTarget == null)
					{
						_bColor = _paper.bitmapData.getPixel(mouseX,mouseY);
						storeColor();
						if(!_colorTool.visible)
						{
							_ePreview.graphics.clear();
							_ePreview.graphics.lineStyle(1,0xffffff,0.65);
							_ePreview.graphics.beginFill(_bColor);
							_ePreview.graphics.drawRoundRect(-72,-72,64,64,8,8);
							_ePreview.graphics.endFill();
						}
					}
					else
					{
						var ctx:int = mouseX - (_colorTool.x + _colorTarget.x);
						if(ctx < 0)
							ctx = 0;
						if(ctx > 400)
							ctx = 400;
						var percent:Number = ctx/400;
						if(_colorTarget == _barBrt)
						{
							_valBrt = percent;
							updateColorBox();
						}
						else if(_colorTarget == _barSat)
						{
							_valSat = percent;
							updateColorBox();
						}
						else if(_colorTarget == _barHue)
						{
							_valHue = percent*360;
							updateColorBox();
						}
					}
				}
			}
			else 
			{
				//Paint behavior
				_brush.x = mouseX - uint(_brush.width/2);
				_brush.y = mouseY - uint(_brush.height/2);
				_bReticle.x = _brush.x;
				_bReticle.y = _brush.y;
				if(_painting)
				{
					//Figure out exactly where to draw this event
					var i:uint;
					var numPoints:uint = 1;
					var xPoints:Array;
					var yPoints:Array;
					if(_bLerp && (_bOld != null))
					{
						//fill up points array
						var ratio:Number;
						var dx:Number = _brush.x - _bOld.x;
						var dy:Number = _brush.y - _bOld.y;
						var df:Number = (_brush.width+_brush.height)/30;
						if(df < 1)
							df = 1;
						numPoints = Math.sqrt(dx*dx+dy*dy)/df;
						if(numPoints < 1)
							numPoints = 1;
						else
						{
							xPoints = new Array(numPoints);
							yPoints = new Array(numPoints);
							for(i = 0; i < numPoints; i++)
							{
								ratio = i/numPoints;
								xPoints[i] = _brush.x - ratio*dx;
								yPoints[i] = _brush.y - ratio*dy;
							}
						}
					}
					if(numPoints == 1)
					{
						xPoints = [ _brush.x ];
						yPoints = [ _brush.y ];
					}
					
					//Actually draw to the overlay
					for(i = 0; i < numPoints; i++)
					{
						_bMtx.identity();
						_bMtx.translate(xPoints[i],yPoints[i]);
						_overlay.bitmapData.draw(_brush.bitmapData, _bMtx);
					}
				}
				if(_bOld == null)
					_bOld = new Point();
				_bOld.x = _brush.x;
				_bOld.y = _brush.y;
			}
		}
		
		/**
		 * Internal event handler for input and focus.
		 */
		protected function onMouseDown(event:MouseEvent):void
		{
			onMouseMove(event);
		}
		
		/**
		 * Internal event handler for input and focus.
		 */
		protected function onMouseUp(event:MouseEvent):void
		{
			_colorTarget = null;
			if(_eyedropMode)
				_painting = false;
			else
				applyOverlay();
		}
		
		/**
		 * Internal event handler for input and focus.
		 */
		protected function onKeyUp(event:KeyboardEvent):void
		{
			var refreshBrush:Boolean = false;
			
			var c:int = event.keyCode;
			switch(c)
			{
				//Brush toggle hotkeys
				case 66:
					_bToggle = !_bToggle;
					refreshBrush = true;
					break;
				
				//Eyedropper hotkeys
				case 16:
					_kShift = false;
					_eyedropMode = _kAlt || _kCtrl;
					refreshBrush = !_eyedropMode;
					break;
				case 17:
					_kCtrl = false;
					_eyedropMode = _kAlt || _kShift;
					refreshBrush = !_eyedropMode;
					break;
				case 18:
					_kAlt = false;
					_eyedropMode = _kCtrl || _kShift;
					refreshBrush = !_eyedropMode;
					break;
				
				//Brush alpha hotkeys
				case 48:
					_oCT.alphaMultiplier = 1;
					refreshBrush = true;
					break;
				case 49:
					_oCT.alphaMultiplier = 0.1;
					refreshBrush = true;
					break;
				case 50:
					_oCT.alphaMultiplier = 0.2;
					refreshBrush = true;
					break;
				case 51:
					_oCT.alphaMultiplier = 0.3;
					refreshBrush = true;
					break;
				case 52:
					_oCT.alphaMultiplier = 0.4;
					refreshBrush = true;
					break;
				case 53:
					_oCT.alphaMultiplier = 0.5;
					refreshBrush = true;
					break;
				case 54:
					_oCT.alphaMultiplier = 0.6;
					refreshBrush = true;
					break;
				case 55:
					_oCT.alphaMultiplier = 0.7;
					refreshBrush = true;
					break;
				case 56:
					_oCT.alphaMultiplier = 0.8;
					refreshBrush = true;
					break;
				case 57:
					_oCT.alphaMultiplier = 0.9;
					refreshBrush = true;
					break;
			
				//Color tool toggle
				case 32: //space bar
					_colorTool.visible = false;
					refreshBrush = true;
					break;
				default:
					break;
			}
			
			if(refreshBrush)
				resizeBrush();
		}
		
		/**
		 * Internal event handler for input and focus.
		 */
		protected function onKeyDown(event:KeyboardEvent):void
		{
			var refreshBrush:Boolean = false;
			
			var c:int = event.keyCode;
			switch(c)
			{
				//Help controls
				case 72:
					_help.visible = !_help.visible;
					break;
				
				//Mirroring controls
				case 70:
				case 77:
					if(!_painting)
					{
						var oldAlpha:Number = _oCT.alphaMultiplier;
						_oCT.alphaMultiplier = 1;
						var _flipMtx:Matrix = new Matrix();
						_flipMtx.scale(-1,1);
						_flipMtx.translate(_w,0);
						_overlay.bitmapData.draw(_paper.bitmapData,_flipMtx);
						applyOverlay();
						_oCT.alphaMultiplier = oldAlpha;
					}
					break;
				
				//Eyedropper controls
				case 16:
					_kShift = true;
					_eyedropMode = true;
					onMouseMove();
					break;
				case 17:
					_kCtrl = true;
					_eyedropMode = true;
					onMouseMove();
					break;
				case 18:
					_kAlt = true;
					_eyedropMode = true;
					onMouseMove();
					break;
				
				//Brush size controls
				case 189: //minus
				case 219: //left bracket
					if((_bToggle?_bCurSize2:_bCurSize1) > 0)
					{
						if(_bToggle)
							_bCurSize2--;
						else
							_bCurSize1--;
						refreshBrush = true;
					}
					break;
				case 187: //plus
				case 221: //right bracket
					if((_bToggle?_bCurSize2:_bCurSize1) < _bSizes.length-1)
					{
						if(_bToggle)
							_bCurSize2++;
						else
							_bCurSize1++;
						refreshBrush = true;
					}
					break;
				
				//Color tool toggle
				case 32: //space bar
					if(!_colorTool.visible)
					{
						_colorTool.visible = true;
						_colorOld.bitmapData.fillRect(_cr,_bColor);
						updateColorBox();
					}
					break;
				default:
					break;
			}
			
			if(refreshBrush)
				resizeBrush();
		}
		
		/**
		 * Internal event handler for input and focus.
		 */
		protected function onMouseOut(event:MouseEvent):void
		{
			//applyOverlay();
		}
		
		/**
		 * Internal event handler for input and focus.
		 */
		protected function onMouseOver(event:MouseEvent):void
		{
			Mouse.hide();
		}
		
		/**
		 * Internal event handler for input and focus.
		 */
		protected function onFocus(event:Event=null):void
		{
			Mouse.hide();
			_focus.visible = false;
		}
		
		/**
		 * Internal event handler for input and focus.
		 */
		protected function onFocusLost(event:Event=null):void
		{
			Mouse.show();
			applyOverlay();
			_focus.visible = true;
		}
		
		/**
		 * Internal event handler for input and focus.
		 */
		protected function onResize(event:Event=null):void
		{
			_w = stage.stageWidth;
			_h = stage.stageHeight;
			resizePaper();
			_colorTool.y = _h;
			_colorTool.x = (_w-_colorTool.width)/2;
			_focus.y = _h-20;
		}
	}
}
