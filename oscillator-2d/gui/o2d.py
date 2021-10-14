import pygame, sys
import numpy as np
import subprocess
import time
import json
from math import sqrt
from timeit import default_timer as timer

# text box initialization
def update_message (message):
	font = pygame.font.Font('./avenir_regular.ttf', 14)
	#text = font.render(message, 1, TEXT_COLOR)
	#text_rect = text.get_rect(center =(WIDTH / 2, HEIGHT-50))
	#screen.fill (TEXT_BG_COLOR, (0, HEIGHT-TEXTHEIGHT, WIDTH, TEXTHEIGHT))
	#screen.blit(text, text_rect)
	textsurface = font.render(message, 1, TEXT_COLOR)
	text_rect = textsurface.get_rect(center =(WIDTH / 2, HEIGHT-BUFFER-TEXTHEIGHT/2))
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
# TODO refactor this ugly thing
def update_figures(ball_xy):
	#screen.fill (BG_COLOR, (0, 0, WIDTH, HEIGHT-TEXTHEIGHT)) # reset screen first
	gradientBG()
	ball_x_ = BUFFER + ball_xy[0]
	ball_y_ = BUFFER + ball_xy[1]
	ball_xy_ = (ball_x_, ball_y_)

	# draw the spring(s) for fun
	spring1_circle_first_xy = SPRING1_ORIGIN_XY
	spring1_circle_last_xy = ball_xy_
	spring1_circle_xdelta = (spring1_circle_last_xy[0]-spring1_circle_first_xy[0]) /(N_SPRING_CIRCLE-1)
	spring1_circle_ydelta = (spring1_circle_last_xy[1]-spring1_circle_first_xy[1]) /(N_SPRING_CIRCLE-1)

	spring2_circle_first_xy = SPRING2_ORIGIN_XY
	spring2_circle_last_xy = ball_xy_
	spring2_circle_xdelta = (spring2_circle_last_xy[0]-spring2_circle_first_xy[0]) /(N_SPRING_CIRCLE-1)
	spring2_circle_ydelta = (spring2_circle_last_xy[1]-spring2_circle_first_xy[1]) /(N_SPRING_CIRCLE-1)

	spring3_circle_first_xy = SPRING3_ORIGIN_XY
	spring3_circle_last_xy = ball_xy_
	spring3_circle_xdelta = (spring3_circle_last_xy[0]-spring3_circle_first_xy[0]) /(N_SPRING_CIRCLE-1)
	spring3_circle_ydelta = (spring3_circle_last_xy[1]-spring3_circle_first_xy[1]) /(N_SPRING_CIRCLE-1)

	spring4_circle_first_xy = SPRING4_ORIGIN_XY
	spring4_circle_last_xy = ball_xy_
	spring4_circle_xdelta = (spring4_circle_last_xy[0]-spring4_circle_first_xy[0]) /(N_SPRING_CIRCLE-1)
	spring4_circle_ydelta = (spring4_circle_last_xy[1]-spring4_circle_first_xy[1]) /(N_SPRING_CIRCLE-1)

	x = spring1_circle_first_xy[0]
	y = spring1_circle_first_xy[1]
	for i in range(N_SPRING_CIRCLE):
		pygame.draw.circle(
			screen,
			SPRING_COLOR,
			(x, y), # center coordinate
			SPRING_CIRCLE_RADIUS,
			1
		)
		x += spring1_circle_xdelta
		y += spring1_circle_ydelta

	x = spring2_circle_first_xy[0]
	y = spring2_circle_first_xy[1]
	for i in range(N_SPRING_CIRCLE):
		pygame.draw.circle(
			screen,
			SPRING_COLOR,
			(x, y), # center coordinate
			SPRING_CIRCLE_RADIUS,
			1
		)
		x += spring2_circle_xdelta
		y += spring2_circle_ydelta

	x = spring3_circle_first_xy[0]
	y = spring3_circle_first_xy[1]
	for i in range(N_SPRING_CIRCLE):
		pygame.draw.circle(
			screen,
			SPRING_COLOR,
			(x, y), # center coordinate
			SPRING_CIRCLE_RADIUS,
			1
		)
		x += spring3_circle_xdelta
		y += spring3_circle_ydelta

	x = spring4_circle_first_xy[0]
	y = spring4_circle_first_xy[1]
	for i in range(N_SPRING_CIRCLE):
		pygame.draw.circle(
			screen,
			SPRING_COLOR,
			(x, y), # center coordinate
			SPRING_CIRCLE_RADIUS,
			1
		)
		x += spring4_circle_xdelta
		y += spring4_circle_ydelta

	# draw the lonely soul
	pygame.draw.circle(
		screen,
		BALL_COLOR,
		(ball_x_, ball_y_), # center coordinate
		BALL_RADIUS,
		0 # fill the circle
	)

	pygame.display.update()

# scene setup
BALL_X_OFFSET = 150
BALL_Y = 300

BUFFER = 100
WIDTH = 600 + BUFFER*2
TEXTHEIGHT = 100
HEIGHT = 600 + BUFFER*2 + TEXTHEIGHT

SPRING1_ORIGIN_XY = (BUFFER, BUFFER)
SPRING2_ORIGIN_XY = (WIDTH-BUFFER, BUFFER)
SPRING3_ORIGIN_XY = (WIDTH-BUFFER, HEIGHT-TEXTHEIGHT-BUFFER)
SPRING4_ORIGIN_XY = (BUFFER, HEIGHT-TEXTHEIGHT-BUFFER)

BALL_RADIUS = 30
SPRING_CIRCLE_RADIUS = 10
N_SPRING_CIRCLE = 20
MESSAGE = "A trapped soul's coordinates brewing on StarkNet ...".upper()

COLOR_DARK_PINK = (229,2,120)
COLOR_SKY_BLUE = (0,190,240)
COLOR_WHITE = (255,255,255)
COLOR_CREAMY_YELLOW = (255,230,148)

BG_TOP_COLOR = COLOR_DARK_PINK
BG_BOTTOM_COLOR = COLOR_SKY_BLUE
BALL_COLOR = COLOR_CREAMY_YELLOW
SPRING_COLOR = COLOR_WHITE
TEXT_COLOR = COLOR_WHITE

# contract setup
CONTRACT_ADDRESS = '0x330a37a2625ba67f790f45276a6447d49fcdf9a5165dd02e90f6fc9dfbb7fd9'
SCALE_FP = 10000 # for fixed-point arithmetic
PRIME = 3618502788666131213697322783095070105623107215331596699973092056135872020481
PRIME_HALF = PRIME//2

pygame.init()
screen = pygame.display.set_mode( (WIDTH, HEIGHT) )
pygame.display.set_caption( 'O2D' )

#screen.fill( BG_COLOR )
gradientBG()

# initial condition
x  = 150
xd = 500
y  = 200
yd = 0
t  = 0
dt = 0.02

t_fp  = int( t * SCALE_FP )
dt_fp = int( dt * SCALE_FP )
x_fp  = int( x * SCALE_FP )
xd_fp = int( xd * SCALE_FP )
y_fp  = int( y * SCALE_FP )
yd_fp = int( yd * SCALE_FP )

update_figures(
	ball_xy = (x,y)
)
update_message(MESSAGE)

while True:
	# retrieve N sample from contract
	N = 400
	print(f'> Begin retrieval of {N} coordinates from StarkNet rk4 integrator.')

	x_fp_s  = [x_fp]
	xd_fp_s = [xd_fp]
	y_fp_s  = [y_fp]
	yd_fp_s = [yd_fp]
	for i in range(N):

		# sending side must mod P to send only positive felt values; receiving side could receive negative value
		f_mod_P = lambda x : x if x>=0 else x+PRIME
		x_fp  = f_mod_P (x_fp)
		xd_fp = f_mod_P (xd_fp)
		y_fp  = f_mod_P (y_fp)
		yd_fp = f_mod_P (yd_fp)

		cmd = f"starknet call --network=alpha --address {CONTRACT_ADDRESS} --abi o2d_contract_abi.json " + \
			f"--function query_next_given_coordinates --inputs {t_fp} {dt_fp} {x_fp} {xd_fp} {y_fp} {yd_fp}"
		cmd = cmd.split(' ')
		#time_start = timer()
		result = subprocess_run(cmd)
		#time_end = timer()
		#print(f'> retrieval takes {time_end-time_start} sec')

		result = result.split(' ')
		x_fp  = int(result[0])
		xd_fp = int(result[1])
		y_fp  = int(result[2])
		yd_fp = int(result[3])
		t_fp += dt_fp

		x_fp_s.append(  x_fp )
		xd_fp_s.append( xd_fp )
		y_fp_s.append(  y_fp )
		yd_fp_s.append( yd_fp )
		print(f'> {i+1}th/{N} coordinate retrieved from StarkNet rk4 integrator.')
	print()

	x_s = [x_fp/SCALE_FP for x_fp in x_fp_s]
	y_s = [y_fp/SCALE_FP for y_fp in y_fp_s]
	print(f'> printing all retrieved coordinates:\n')
	for i in range(len(x_s)):
		print(f'({x_s[i]},{y_s[i]})', end=' ')
	print()

	# saving the last coordinate for next loop
	x_fp  = x_fp_s[-1]
	xd_fp = xd_fp_s[-1]
	y_fp  = y_fp_s[-1]
	yd_fp = yd_fp_s[-1]

	# render animation from retrieved coordinates
	print('>>> Begin animation rendering.')
	for i in range(N):
		update_figures(
			ball_xy = (x_s[i], y_s[i])
		)

		time.sleep(0.01)

	# check for quit() event
	for event in pygame.event.get():
		if event.type == pygame.QUIT:
			sys.exit()

