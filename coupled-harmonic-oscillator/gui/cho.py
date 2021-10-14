import pygame, sys
import numpy as np
import subprocess
import time
import json
from timeit import default_timer as timer

# text box initialization
def update_message (message):
	font = pygame.font.Font('./avenir_regular.ttf', 14)
	#text = font.render(message, 1, TEXT_COLOR)
	#text_rect = text.get_rect(center =(WIDTH / 2, HEIGHT-50))
	#screen.fill (TEXT_BG_COLOR, (0, HEIGHT-TEXTHEIGHT, WIDTH, TEXTHEIGHT))
	#screen.blit(text, text_rect)
	textsurface = font.render(message, 1, TEXT_COLOR)
	text_rect = textsurface.get_rect(center =(WIDTH / 2, HEIGHT-TEXTHEIGHT/1.5))
	screen.blit(textsurface,text_rect)

	pygame.display.update()

# utility function to execute shell command and parse result
def subprocess_run (cmd):
	result = subprocess.run(cmd, stdout=subprocess.PIPE)
	result = result.stdout.decode('utf-8')[:-1] # remove trailing newline
	return result

def gradientBG():
	""" Draw a horizontal-gradient filled rectangle covering <target_rect> """
	target_rect = pygame.Rect(0, 0, WIDTH, HEIGHT)
	color_rect = pygame.Surface( (2,2) )
	pygame.draw.line( color_rect, BG_TOP_COLOR,  (0,0), (1,0) ) # top color line
	pygame.draw.line( color_rect, BG_BOTTOM_COLOR, (0,1), (1,1) ) # bottom color line
	color_rect = pygame.transform.smoothscale( color_rect, (target_rect.width,target_rect.height ) )  # stretch
	screen.blit( color_rect, target_rect ) # paint

# redraw the screen and the mass at new x location
def update_figures(ball1_x, ball2_x):
	#screen.fill (BG_COLOR, (0, 0, WIDTH, HEIGHT-TEXTHEIGHT)) # reset screen first
	gradientBG()
	ball1_x_ = BALL_X_OFFSET + ball1_x
	ball2_x_ = BALL_X_OFFSET + ball2_x

	# draw the spring(s) for fun
	spring1_circle_first_x = BALL_X_OFFSET + SPRING_CIRCLE_RADIUS
	spring1_circle_last_x = ball1_x_
	spring1_circle_distance = (spring1_circle_last_x - spring1_circle_first_x)/(N_SPRING_CIRCLE-1)

	spring2_circle_first_x = ball1_x_ + BALL1_RADIUS + SPRING_CIRCLE_RADIUS
	spring2_circle_last_x = ball2_x_ - BALL2_RADIUS - SPRING_CIRCLE_RADIUS
	spring2_circle_distance = (spring2_circle_last_x - spring2_circle_first_x)/(N_SPRING_CIRCLE-1)

	spring3_circle_first_x = ball2_x_
	spring3_circle_last_x = RIGHTMOST - SPRING_CIRCLE_RADIUS
	spring3_circle_distance = (spring3_circle_last_x - spring3_circle_first_x)/(N_SPRING_CIRCLE-1)

	x = spring1_circle_first_x
	for i in range(N_SPRING_CIRCLE):
		pygame.draw.circle(
			screen,
			SPRING_COLOR,
			(x, BALL_Y), # center coordinate
			SPRING_CIRCLE_RADIUS,
			1
		)
		x += spring1_circle_distance

	x = spring2_circle_first_x
	for i in range(N_SPRING_CIRCLE):
		pygame.draw.circle(
			screen,
			SPRING_COLOR,
			(x, BALL_Y), # center coordinate
			SPRING_CIRCLE_RADIUS,
			1
		)
		x += spring2_circle_distance

	x = spring3_circle_first_x
	for i in range(N_SPRING_CIRCLE):
		pygame.draw.circle(
			screen,
			SPRING_COLOR,
			(x, BALL_Y), # center coordinate
			SPRING_CIRCLE_RADIUS,
			1
		)
		x += spring3_circle_distance

	# draw ball 1
	pygame.draw.circle(
		screen,
		BALL_COLOR,
		(ball1_x_, BALL_Y), # center coordinate
		BALL1_RADIUS,
		0 # fill the circle
	)

	# draw ball 2
	pygame.draw.circle(
		screen,
		BALL_COLOR,
		(ball2_x_, BALL_Y), # center coordinate
		BALL2_RADIUS,
		0 # fill the circle
	)

	pygame.display.update()

# scene setup
BALL_X_OFFSET = 150
BALL_Y = 300

WIDTH = 1000 + BALL_X_OFFSET*2
RIGHTMOST = WIDTH - BALL_X_OFFSET
TEXTHEIGHT = 100
HEIGHT = 600+TEXTHEIGHT
BALL1_RADIUS = 30      # reflect ball1 mass
BALL2_RADIUS = 30*1.26 # reflect ball2 mass; 1.26^3 ~= 2
SPRING_CIRCLE_RADIUS = 10
N_SPRING_CIRCLE = 20
MESSAGE = "Coupled Harmonic Oscillator coordinates brewing on StarkNet ...".upper()

COLOR_LIGHT_ORANGE = (238,84,56)
COLOR_DIRT_GREEN = (167,154,88)
COLOR_WHITE_GREEN = (212,207,167)
COLOR_WINE_RED = (160,49,47)
COLOR_BLOOD_RED = (155,46,41)
COLOR_REDDISH_BLACK = (10,0,0)
COLOR_DARK_GREEN = (167,154,88)
COLOR_BROWN = (131,76,45)
COLOR_PINK = (240,133,97)
COLOR_SHADE_GREEN = (164,155,81)
COLOR_GREY_GREEN = (185,175,150)

BG_COLOR = COLOR_WINE_RED
BG_TOP_COLOR = COLOR_PINK
BG_BOTTOM_COLOR = COLOR_BLOOD_RED
BALL_COLOR = COLOR_SHADE_GREEN
SPRING_COLOR = COLOR_BLOOD_RED
TEXT_BG_COLOR = COLOR_DARK_GREEN
TEXT_COLOR = (185,175,150)

# contract setup
CONTRACT_ADDRESS = '0x507a912e391f71a0440b8886fbbc16ec7cf3bf65887417536eb38e5245f0df1'
SCALE_FP = 10000 # for fixed-point arithmetic
PRIME = 3618502788666131213697322783095070105623107215331596699973092056135872020481
PRIME_HALF = PRIME//2

pygame.init()
screen = pygame.display.set_mode( (WIDTH, HEIGHT) )
pygame.display.set_caption( 'CHO' )

#screen.fill( BG_COLOR )
gradientBG()

# initial condition
x1 = 150
x1d = 0
x2 = 800
x2d = 1000
t = 0
dt = 0.01

t_fp  = int( t * SCALE_FP )
dt_fp = int( dt * SCALE_FP )
x1_fp  = int( x1 * SCALE_FP )
x1d_fp = int( x1d * SCALE_FP )
x2_fp  = int( x2 * SCALE_FP )
x2d_fp = int( x2d * SCALE_FP )

update_figures(
	ball1_x = x1,
	ball2_x = x2
)
update_message(MESSAGE)

while True:
	# retrieve N sample from contract
	N = 300
	print(f'> Begin retrieval of {N} coordinates from StarkNet rk4 integrator.')

	x1_fp_s  = [x1_fp]
	x1d_fp_s = [x1d_fp]
	x2_fp_s  = [x2_fp]
	x2d_fp_s = [x2d_fp]
	for i in range(N):

		# sending side must mod P to send only positive felt values; receiving side could receive negative value
		f_mod_P = lambda x : x if x>=0 else x+PRIME
		x1_fp  = f_mod_P (x1_fp)
		x1d_fp = f_mod_P (x1d_fp)
		x2_fp  = f_mod_P (x2_fp)
		x2d_fp = f_mod_P (x2d_fp)

		cmd = f"starknet call --network=alpha --address {CONTRACT_ADDRESS} --abi cho_contract_abi.json " + \
			f"--function query_next_given_coordinates --inputs {t_fp} {dt_fp} {x1_fp} {x1d_fp} {x2_fp} {x2d_fp}"
		cmd = cmd.split(' ')
		result = subprocess_run(cmd)

		result = result.split(' ')
		x1_fp  = int(result[0])
		x1d_fp = int(result[1])
		x2_fp  = int(result[2])
		x2d_fp = int(result[3])
		t_fp += dt_fp

		x1_fp_s.append( x1_fp )
		x1d_fp_s.append( x1d_fp )
		x2_fp_s.append( x2_fp )
		x2d_fp_s.append( x2d_fp )
		print(f'> {i+1}th/{N} coordinate retrieved from StarkNet rk4 integrator.')
	print()

	x1_s = [x1_fp/SCALE_FP for x1_fp in x1_fp_s]
	x2_s = [x2_fp/SCALE_FP for x2_fp in x2_fp_s]
	print(f'> printing all retrieved coordinates: {x1_s}\n  {x2_s}\n')

	# saving the last coordinate for next loop
	x1_fp = x1_fp_s[-1]
	x1d_fp = x1d_fp_s[-1]
	x2_fp = x2_fp_s[-1]
	x2d_fp = x2d_fp_s[-1]

	# render animation from retrieved coordinates
	print('>>> Begin animation rendering.')
	update_message(f'Rendering {N} coordinates received from StarkNet!'.upper() )
	for i in range(N):
		update_figures(
			ball1_x = x1_s[i],
			ball2_x = x2_s[i]
		)
		if i==N-1:
			update_message(MESSAGE)

		time.sleep(0.01)

	# check for quit() event
	for event in pygame.event.get():
		if event.type == pygame.QUIT:
			sys.exit()

