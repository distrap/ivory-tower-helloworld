module Main where

import Hello.Tests.Platforms
import Hello.Tests.I2CWhoAmI (app)

main :: IO ()
main = buildHelloApp iot01a app
