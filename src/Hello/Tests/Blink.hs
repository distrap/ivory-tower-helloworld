{-# LANGUAGE DataKinds #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleContexts #-}

module Hello.Tests.Blink where

import Ivory.Language
import Ivory.Tower
import Ivory.HW.Module

import Hello.Tests.Platforms
import Ivory.BSP.STM32.ClockConfig

import Ivory.Tower.Base.LED hiding (blink, blinker, ledController)
------------------------------

-- | LED Controller: Given a set of leds and a control channel of booleans,
--   setup the pin hardware, and turn the leds on when the control channel is
--   true.
ledController :: [LED] -> ChanOutput ('Stored IBool) -> Monitor e ()
ledController leds rxer = do
  -- Bookkeeping: this task uses Ivory.HW.Module.hw_moduledef
  monitorModuleDef $ hw_moduledef
  -- Setup hardware before running any event handlers
  handler systemInit "hardwareinit" $
    callback $ const $ mapM_ ledSetup leds
  -- Run a callback on each message posted to the channel
  handler rxer "newoutput" $ callback $ \outref -> do
    out <- deref outref
    -- Turn pins on or off according to event value
    ifte_ out
      (mapM_ ledOn  leds)
      (mapM_ ledOff leds)

-- | Blink task: Given a period and a channel source, output an alternating
--   stream of true / false on each period.
blinker :: Time a => a -> Tower e (ChanOutput ('Stored IBool))
blinker t = do
  p_chan <- period t
  (cin, cout) <- channel
  monitor "blinker" $ do
    lastled <- stateInit "lastled" (ival false)
    handler p_chan "per" $  do
      e <- emitter cin 1
      callback $ \timeref -> do
        time <- deref timeref
        -- Emit boolean value which will alternate each period.
        store lastled (time .% (2*p) <? p)
        emitV e (time .% (2*p) <? p)
  return cout
  where p = toITime t

blink :: Time a => a -> [LED] -> Tower p ()
blink per pins = do
  onoff <- blinker per
  monitor "led" $ ledController pins onoff

app :: (e -> ClockConfig) -> (e -> Platform) -> Tower e ()
app _tocc toPlatform = do
  Platform{..} <- fmap toPlatform getEnv
  blink (Milliseconds 1000) [platformRedLED]
  blink (Milliseconds 666) [platformGreenLED]
